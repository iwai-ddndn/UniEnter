#if DEBUG
import AppKit
import CryptoKit
import SwiftUI

/// アプリの全画面をPNGとして書き出す開発用モード。
///
/// `UniEnter.app --screenshot-mode <出力ディレクトリ>` で起動すると、常駐処理を一切始めずに
/// 各SwiftUIビューをオフスクリーンに描画してPNGを保存し、終了する。
///
/// - 実ウィンドウを画面に出さないので、画面収録権限も実機操作も不要。
/// - 設定・ライセンスの状態は専用のUserDefaults suiteと使い捨ての署名鍵で作るため、
///   実際のユーザー設定やライセンス状態を読みも書きもしない。
/// - ファイル名は固定。毎回上書きされるので、出力先は常に最新の状態になる。
///
/// 撮れないもの: メニューバーのドロップダウン(NSMenuはOSが描画するため、
/// この方式では取得できない)。
enum ScreenshotMode {
    static let flag = "--screenshot-mode"

    /// 起動引数に `--screenshot-mode` があれば全画面を書き出して終了する。
    /// 通常起動なら false を返し、呼び出し元は普段どおりの初期化を続ける。
    @MainActor
    static func runIfRequested() -> Bool {
        let args = CommandLine.arguments
        guard let i = args.firstIndex(of: flag) else { return false }
        guard i + 1 < args.count else {
            FileHandle.standardError.write(Data("\(flag) には出力ディレクトリが必要です\n".utf8))
            exit(2)
        }
        let outDir = URL(fileURLWithPath: args[i + 1], isDirectory: true)
        do {
            try capture(into: outDir)
        } catch {
            FileHandle.standardError.write(Data("スクリーンショット生成に失敗: \(error)\n".utf8))
            exit(1)
        }
        exit(0)
    }

    // MARK: - 撮影対象

    /// 1枚のスクリーンショットの定義。`name` がそのままファイル名(拡張子なし)になる。
    ///
    /// `make` はクロージャにしてある。ライト/ダークで同じビューを使い回すと
    /// @State や描画キャッシュが持ち越されるため、1枚ごとに作り直す。
    private struct Shot {
        let name: String
        /// INDEX.md に載せる説明
        let caption: String
        let make: @MainActor () -> AnyView
    }

    @MainActor
    private static func allShots() -> [Shot] {
        let noop: () -> Void = {}

        return [
            Shot(name: "01-onboarding",
                 caption: "オンボーディング(アクセシビリティ許可の誘導)",
                 make: { AnyView(OnboardingView(openSystemSettings: noop, requestPrompt: noop)) }),
            Shot(name: "02-onboarding-troubleshooting",
                 caption: "オンボーディング(10秒経過後に出るトラブルシューティング付き)",
                 make: { AnyView(OnboardingView(openSystemSettings: noop,
                                                requestPrompt: noop,
                                                showTroubleshooting: true)) }),
            Shot(name: "03-tutorial-1-keys",
                 caption: "チュートリアル 1/2 — 覚えるのは2つだけ",
                 make: { AnyView(tutorialView(step: 0)) }),
            Shot(name: "04-tutorial-2-sendkey",
                 caption: "チュートリアル 2/2 — Enter=改行設定のアプリを確認(LINE/Slackとも自動検出の例)",
                 make: {
                     // 両方の自動検出バッジの見え方を確認できるよう、LINEは「改行」検出・
                     // Slackは「既定のまま」検出の体で撮る
                     let model = settingsModel()
                     model.detectedSendKeys = [
                         SendKeyDetector.lineBundleID: .cmdEnterSend,
                         SendKeyDetector.slackBundleID: .standard,
                     ]
                     return AnyView(tutorialView(step: 1, model: model))
                 }),
            Shot(name: "05-settings",
                 caption: "設定(既定状態)",
                 make: { AnyView(SettingsView(model: settingsModel())) }),
            Shot(name: "06-settings-advanced",
                 caption: "設定(詳細オプション: アプリ側の送信キー を展開、LINE/Slackとも自動検出の例)",
                 make: {
                     // 両方の自動検出バッジの見え方を確認できるよう、LINEは「改行」検出・
                     // Slackは「既定のまま」検出の体で撮る
                     let model = settingsModel()
                     model.detectedSendKeys = [
                         SendKeyDetector.lineBundleID: .cmdEnterSend,
                         SendKeyDetector.slackBundleID: .standard,
                     ]
                     model.onRecheckSendKeys = noop
                     return AnyView(SettingsView(model: model, showAdvanced: true))
                 }),
            Shot(name: "07-license-trial",
                 caption: "ライセンス(トライアル中・残り11日)",
                 make: { AnyView(LicenseView(model: licenseModel(.trial))) }),
            Shot(name: "08-license-expired",
                 caption: "ライセンス(トライアル終了・書き換え停止中)",
                 make: { AnyView(LicenseView(model: licenseModel(.expired))) }),
            Shot(name: "09-license-activated",
                 caption: "ライセンス(認証済み)",
                 make: { AnyView(LicenseView(model: licenseModel(.licensed))) }),
        ]
    }

    /// 撮影用のTutorialView。実際のアプリ起動・検出は行わない
    /// (モデルのopenApp/isAppInstalled未配線 = ボタンは出るが押しても何もしない)
    @MainActor
    private static func tutorialView(step: Int, model: SettingsViewModel? = nil) -> TutorialView {
        TutorialView(model: model ?? settingsModel(), finish: {}, step: step)
    }

    // MARK: - 描画

    private static let appearances: [(suffix: String, name: NSAppearance.Name)] = [
        ("light", .aqua),
        ("dark", .darkAqua),
    ]

    @MainActor
    private static func capture(into outDir: URL) throws {
        let fm = FileManager.default
        try fm.createDirectory(at: outDir, withIntermediateDirectories: true)

        let shots = allShots()
        var lines: [String] = []

        for (suffix, appearanceName) in appearances {
            for shot in shots {
                let png = try render(shot: shot, appearance: appearanceName)
                let file = "\(shot.name)-\(suffix).png"
                try png.write(to: outDir.appendingPathComponent(file))
                if suffix == appearances[0].suffix {
                    lines.append("| \(shot.caption) | ![](\(shot.name)-light.png) | ![](\(shot.name)-dark.png) |")
                }
            }
        }

        let count = shots.count * appearances.count
        try writeIndex(lines: lines, count: count, to: outDir)
        try writeGallery(shots: shots, count: count, to: outDir)
        print("スクリーンショット \(count) 枚を書き出しました: \(outDir.path)")
        print("ブラウザで見る: \(outDir.appendingPathComponent("index.html").path)")
    }

    @MainActor
    private static func render(shot: Shot, appearance name: NSAppearance.Name) throws -> Data {
        guard let appearance = NSAppearance(named: name) else {
            throw ScreenshotError.renderFailed(shot.name)
        }
        // 各ビューはウィンドウ背景の上に置かれる前提で背景色を持たない。
        // そのまま撮ると透明背景になり、ダークでは「白地に白文字」になってしまうので、
        // その外観で解決したウィンドウ背景色を明示的に敷く。
        var background = NSColor.windowBackgroundColor
        appearance.performAsCurrentDrawingAppearance {
            background = NSColor.windowBackgroundColor.usingColorSpace(.sRGB) ?? background
        }

        let hosting = NSHostingView(rootView: shot.make())
        hosting.wantsLayer = true
        hosting.layer?.backgroundColor = background.cgColor

        // 画面に出さない台紙ウィンドウ。NSViewはウィンドウに属して初めて
        // appearance が解決され、AppKit製コントロール(Toggle/Picker等)も描画される。
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1, height: 1),
                              styleMask: [.titled],
                              backing: .buffered,
                              defer: false)
        window.appearance = appearance
        window.backgroundColor = background
        window.contentView = hosting

        // ビュー自身が申告するサイズに合わせる(各ビューが .frame で幅を固定している)
        let size = hosting.fittingSize
        window.setContentSize(size)
        hosting.frame = NSRect(origin: .zero, size: size)
        hosting.layoutSubtreeIfNeeded()

        // SwiftUIのレイアウト・画像デコードが落ち着くまでランループを回す
        settleRunLoop()
        window.displayIfNeeded()

        guard let rep = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds) else {
            throw ScreenshotError.renderFailed(shot.name)
        }
        hosting.cacheDisplay(in: hosting.bounds, to: rep)
        guard let data = rep.representation(using: .png, properties: [:]) else {
            throw ScreenshotError.encodeFailed(shot.name)
        }
        try verifyNotBlank(rep: rep, name: shot.name)
        window.contentView = nil
        return data
    }

    /// 描画が空振りしていないかの自己チェック。
    /// 透明背景や描画タイミングのズレでのっぺりした画像が出たら、気付かず放置せず失敗させる。
    private static func verifyNotBlank(rep: NSBitmapImageRep, name: String) throws {
        var distinct = Set<UInt32>()
        let stepX = max(1, rep.pixelsWide / 40)
        let stepY = max(1, rep.pixelsHigh / 40)
        for y in stride(from: 0, to: rep.pixelsHigh, by: stepY) {
            for x in stride(from: 0, to: rep.pixelsWide, by: stepX) {
                guard let c = rep.colorAt(x: x, y: y) else { continue }
                let r = UInt32(c.redComponent * 255), g = UInt32(c.greenComponent * 255)
                let b = UInt32(c.blueComponent * 255), a = UInt32(c.alphaComponent * 255)
                distinct.insert(r << 24 | g << 16 | b << 8 | a)
            }
        }
        // 単色ばかりなら中身が描かれていない
        guard distinct.count >= 3 else {
            throw ScreenshotError.blank(name)
        }
    }

    private static func settleRunLoop() {
        for _ in 0..<12 {
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.02))
        }
    }

    // MARK: - 状態の作り込み

    /// 実際の設定を読み書きしないための使い捨てUserDefaults。
    private static func scratchDefaults() -> UserDefaults {
        let suite = "dev.iwai.UniEnter.screenshot"
        let defaults = UserDefaults(suiteName: suite) ?? .standard
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    /// 実際の設定に依存しない、既定状態(全サービスON)の設定ビューモデル。
    @MainActor
    private static func settingsModel() -> SettingsViewModel {
        SettingsViewModel(store: SettingsStore(defaults: scratchDefaults()))
    }

    private enum LicenseScenario { case trial, expired, licensed }

    /// 目的の状態になる LicenseManager を組み立てる。
    ///
    /// 認証済み状態は、その場で作った使い捨てEd25519鍵ペアで署名したキーを使い、
    /// 対応する公開鍵を LicenseManager に注入して再現する(本番の秘密鍵は不要)。
    @MainActor
    private static func licenseModel(_ scenario: LicenseScenario) -> LicenseViewModel {
        let defaults = scratchDefaults()
        let marker = FileManager.default.temporaryDirectory
            .appendingPathComponent("unienter-screenshot-\(UUID().uuidString)/.trial")

        let privateKey = Curve25519.Signing.PrivateKey()
        let publicKeyBase64 = privateKey.publicKey.rawRepresentation.base64EncodedString()

        // 「今」を固定して、残日数が毎回同じになるようにする
        let now = Date(timeIntervalSince1970: 1_780_000_000)

        switch scenario {
        case .trial:
            // 3日経過 → 残り11日
            defaults.set(now.addingTimeInterval(-3 * 86_400).timeIntervalSince1970, forKey: "trialStartedAt")
        case .expired:
            defaults.set(now.addingTimeInterval(-20 * 86_400).timeIntervalSince1970, forKey: "trialStartedAt")
        case .licensed:
            let payload = try! JSONSerialization.data(withJSONObject: ["email": "sample@example.com"])
            let signature = try! privateKey.signature(for: payload)
            let key = LicenseManager.keyPrefix
                + payload.base64urlEncodedString() + "." + signature.base64urlEncodedString()
            defaults.set(key, forKey: "licenseKey")
        }

        let manager = LicenseManager(defaults: defaults,
                                     markerURL: marker,
                                     publicKeyBase64: publicKeyBase64,
                                     now: { now })
        return LicenseViewModel(manager: manager)
    }

    // MARK: - INDEX.md

    private static func writeIndex(lines: [String], count: Int, to outDir: URL) throws {
        let body = """
        # UniEnter 画面一覧(自動生成)

        `scripts/screenshots.sh` で生成。**このファイルと配下のPNGは手で編集しない**
        (実行のたびに同じファイル名で上書きされる = 常に最新)。

        全 \(count) 枚。撮影対象を増やす場合は `UniEnter/Debug/ScreenshotMode.swift` の
        `allShots()` に追記する。

        > メニューバーのドロップダウン(NSMenu)はOSが描画するため、この方式では撮影できない。

        | 画面 | ライト | ダーク |
        | --- | --- | --- |
        \(lines.joined(separator: "\n"))
        """
        try body.write(to: outDir.appendingPathComponent("INDEX.md"), atomically: true, encoding: .utf8)
    }

    // MARK: - index.html(ブラウザで見る用のギャラリー)

    /// 依存なしの単一HTML。ライト/ダークの切り替えと、実寸(@1x)表示に対応する。
    private static func writeGallery(shots: [Shot], count: Int, to outDir: URL) throws {
        let cards = shots.map { shot in
            """
                <figure class="card">
                  <img data-name="\(shot.name)" src="\(shot.name)-light.png" alt="\(shot.caption)">
                  <figcaption>\(shot.caption)</figcaption>
                </figure>
            """
        }.joined(separator: "\n")

        let html = """
        <!doctype html>
        <html lang="ja">
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>UniEnter 画面一覧</title>
        <style>
          :root { color-scheme: light dark; --bg:#fff; --fg:#37352f; --muted:#787774; --line:#e9e9e7; --card:#fff; }
          body.dark { --bg:#191919; --fg:#e9e9e7; --muted:#9b9a97; --line:#333; --card:#202020; }
          * { box-sizing: border-box; }
          body { margin:0; background:var(--bg); color:var(--fg); font:15px/1.7 -apple-system, BlinkMacSystemFont, "Hiragino Sans", sans-serif; }
          header { position:sticky; top:0; z-index:1; display:flex; flex-wrap:wrap; gap:12px; align-items:baseline;
                   padding:16px 24px; background:var(--bg); border-bottom:1px solid var(--line); }
          h1 { margin:0; font-size:17px; }
          .meta { color:var(--muted); font-size:13px; }
          .spacer { flex:1 1 auto; }
          button { font:inherit; font-size:13px; padding:5px 12px; border:1px solid var(--line); border-radius:7px;
                   background:var(--card); color:var(--fg); cursor:pointer; }
          button[aria-pressed="true"] { background:var(--fg); color:var(--bg); border-color:var(--fg); }
          main { display:grid; grid-template-columns:repeat(auto-fill, minmax(320px,1fr)); gap:24px; padding:24px; }
          .card { margin:0; }
          .card img { width:100%; height:auto; border:1px solid var(--line); border-radius:10px;
                      box-shadow:0 1px 3px rgba(0,0,0,.08); background:var(--card); }
          body.actual .card img { width:auto; max-width:100%; }
          figcaption { margin-top:8px; color:var(--muted); font-size:13px; }
          .note { padding:0 24px 32px; color:var(--muted); font-size:13px; }
        </style>
        </head>
        <body>
        <header>
          <h1>UniEnter 画面一覧</h1>
          <span class="meta">\(count) 枚・生成物(<code>./scripts/screenshots.sh</code>)</span>
          <span class="spacer"></span>
          <button id="theme" aria-pressed="false">ダーク表示</button>
          <button id="size" aria-pressed="false">実寸(@1x)</button>
        </header>
        <main>
        \(cards)
        </main>
        <p class="note">
          メニューバーのドロップダウンはOSが描画するため、この一覧には含まれない。<br>
          撮影対象を増やすときは <code>UniEnter/Debug/ScreenshotMode.swift</code> の <code>allShots()</code> に追記する。
        </p>
        <script>
          const imgs = document.querySelectorAll('img[data-name]')
          const theme = document.getElementById('theme')
          const size = document.getElementById('size')
          theme.onclick = () => {
            const dark = theme.getAttribute('aria-pressed') !== 'true'
            theme.setAttribute('aria-pressed', dark)
            theme.textContent = dark ? 'ライト表示' : 'ダーク表示'
            document.body.classList.toggle('dark', dark)
            imgs.forEach(i => { i.src = i.dataset.name + (dark ? '-dark.png' : '-light.png') })
          }
          size.onclick = () => {
            const actual = size.getAttribute('aria-pressed') !== 'true'
            size.setAttribute('aria-pressed', actual)
            size.textContent = actual ? '幅に合わせる' : '実寸(@1x)'
            document.body.classList.toggle('actual', actual)
            // PNGは@2xなので、実寸表示では半分の幅にする
            imgs.forEach(i => { i.style.width = actual ? (i.naturalWidth / 2) + 'px' : '' })
          }
        </script>
        </body>
        </html>
        """
        try html.write(to: outDir.appendingPathComponent("index.html"), atomically: true, encoding: .utf8)
    }

    private enum ScreenshotError: LocalizedError {
        case renderFailed(String)
        case encodeFailed(String)
        case blank(String)

        var errorDescription: String? {
            switch self {
            case .renderFailed(let name): return "\(name) の描画に失敗しました"
            case .encodeFailed(let name): return "\(name) のPNG変換に失敗しました"
            case .blank(let name): return "\(name) がほぼ単色です(中身が描画されていません)"
            }
        }
    }
}
#endif
