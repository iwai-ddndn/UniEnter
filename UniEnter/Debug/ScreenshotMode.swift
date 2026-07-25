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
                 caption: "チュートリアル 1/3 — 覚えるのは2つだけ",
                 make: { AnyView(TutorialView(openSettings: noop, finish: noop, step: 0)) }),
            Shot(name: "04-tutorial-2-apps",
                 caption: "チュートリアル 2/3 — 対象アプリ",
                 make: { AnyView(TutorialView(openSettings: noop, finish: noop, step: 1)) }),
            Shot(name: "05-tutorial-3-safety",
                 caption: "チュートリアル 3/3 — 日本語入力の安全性",
                 make: { AnyView(TutorialView(openSettings: noop, finish: noop, step: 2)) }),
            Shot(name: "06-settings",
                 caption: "設定(既定状態)",
                 make: { AnyView(SettingsView(model: settingsModel())) }),
            Shot(name: "07-settings-advanced",
                 caption: "設定(詳細オプション: アプリ側の送信キー を展開)",
                 make: { AnyView(SettingsView(model: settingsModel(), showAdvanced: true)) }),
            Shot(name: "08-license-trial",
                 caption: "ライセンス(トライアル中・残り11日)",
                 make: { AnyView(LicenseView(model: licenseModel(.trial))) }),
            Shot(name: "09-license-expired",
                 caption: "ライセンス(トライアル終了・書き換え停止中)",
                 make: { AnyView(LicenseView(model: licenseModel(.expired))) }),
            Shot(name: "10-license-activated",
                 caption: "ライセンス(認証済み)",
                 make: { AnyView(LicenseView(model: licenseModel(.licensed))) }),
        ]
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

        try writeIndex(lines: lines, count: shots.count * appearances.count, to: outDir)
        print("スクリーンショット \(shots.count * appearances.count) 枚を書き出しました: \(outDir.path)")
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
