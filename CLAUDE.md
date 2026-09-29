# UniEnter 開発ガイド(Claude Code向け)

macOSのチャットアプリ全般で「Enter=改行、⌘Enter=送信」に統一するメニューバー常駐アプリ。
制作: octo(https://oc-to.com / info@oc-to.com)

## リポジトリ構成

- `UniEnter/` — アプリ本体(Swift + AppKit、設定等のUIのみSwiftUI)
  - `App/` AppDelegate(全体の配線・メニューバー・各ウィンドウ)
  - `EventTap/` EventTapManager(CGEventTap管理)、RemapEngine(書き換え判定の純粋ロジック)
  - `IME/` InputSourceMonitor(TIS入力ソースのキャッシュ)
  - `Browser/` WebAppMatcher(URL→サービス判定の純粋ロジック)、BrowserTabMonitor(AXでのタブURL監視)
  - `License/` LicenseManager(14日トライアル+Ed25519オフラインライセンス)
  - `Settings/` AppRegistry(対象サービス定義)、SettingsStore(UserDefaults)
  - `UI/` 設定・オンボーディング(権限誘導)・チュートリアル・ライセンスの各SwiftUIビュー
- `UniEnterTests/` — RemapEngine / WebAppMatcher / LicenseManager のユニットテスト
- `site/` — LPのソース(Vite + React + Tailwind + shadcn/ui)。ビルド出力は `docs/`
- `docs/` — GitHub Pages公開用(生成物。直接編集しない)
- `scripts/release.sh` — Release ビルド→ dist/ に zip と pkg を生成(公開はしない)
- `scripts/publish.sh` — 「公開して」の一発実行(repo public化 + Pages有効化 + リリース添付)
- `license-signing/` — ライセンス発行。`keys.txt`(秘密鍵)は**git管理外・要バックアップ**
- `notes/` — 内部向けドキュメント(PADDLE-SETUP.md等。docs/はPagesで公開されるため置かない)
- `marketing/` — リリース告知プランとSNS素材。**現行の素材は `marketing/sns/`**(動画・プロフィール画像・投稿画像・プロフィール文。描画元は `site/src/promo/`、ビルド対象外)。公開リポジトリなので機密は置かない
- `screenshots/app/` — アプリ全画面のスクリーンショット(**生成物。手で編集しない**)
- `design/app-icon/` — アプリアイコンのソース(SVG + CoreGraphicsレンダラ `render.swift`)。OG画像のソースは `site/og.html`(headless Chromeで1200×630に撮影)

## ビルド・テスト・実行

```bash
# プロジェクト生成(project.ymlがソースオブトゥルース。ファイル追加時は必ず再実行)
xcodegen generate
# アプリのビルド+ユニットテスト
xcodebuild -project UniEnter.xcodeproj -scheme UniEnter -configuration Debug -derivedDataPath build test
# アプリの起動
open build/Build/Products/Debug/UniEnter.app
# アプリ全画面のスクリーンショット更新(screenshots/app/へ、固定ファイル名で上書き)
./scripts/screenshots.sh
# LPのビルド(docs/へ出力)
cd site && npm run build
# LPのプレビュー(Browser paneで localhost:8123)
# → preview_start name:"docs-preview"(.claude/launch.json定義済み)
```

- 署名は Apple Development 証明書のハッシュ固定(project.yml)。**再ビルドしてもアクセシビリティ許可(TCC)は維持される**。ad-hoc署名("-")に戻すとビルドごとに許可が無効化されるので戻さないこと
- 万一TCCが壊れたら: `tccutil reset Accessibility dev.iwai.UniEnter` → 再起動 → 許可し直し

## 落とし穴(必読)

- **このMacのzshには `log` 関数が定義されており、システムの`log`を覆い隠す。必ず `/usr/bin/log` を使う**
  例: `/usr/bin/log show --last 5m --predicate 'subsystem == "dev.iwai.UniEnter"' --style compact`
- LPプレビューはHTMLがブラウザキャッシュされることがある → `?v=N` を付けて確認する
- macOSのファイルシステムは大文字小文字を区別しない(`support.tsx`と`Support.tsx`は衝突する)
- ChatGPTのMacアプリは2026年7月のCodex統合でbundle IDが `com.openai.codex` に変更済み(旧`com.openai.chat`はAppRegistry.aliasesで対応)
- simple-iconsにはSlack/OpenAI/Microsoft系のアイコンが**ブランド側の要請で収録されていない**(LPでは頭文字タイルでフォールバック)
- CGEventTapコールバック内で同期AX/IPC呼び出しは禁止(タイムアウトでタップが無効化される)。判定は全てキャッシュ参照のみ

## コア設計の要点

- **書き換え**: 対象アプリ/タブが前面のとき、Enter(keycode 36/76)→Shiftフラグ付与=改行、⌘Enter→Cmd除去=送信。受信イベントのin-place改変(新規postしない)。keyUpはactiveRemapsで対に整合
- **IME安全(製品の生命線)**: 変換中のEnterは絶対に書き換えない。判定はAXでは不可能(ElectronがmarkedRange系を未実装)なので、①IME合成イベント(`eventSourceStateID != 1`)素通し ②TISで日本語モード判定(通知でキャッシュ) ③キーシーケンスで変換中を推定(文字キーでON、確定Enter/クリック/アプリ切替等でOFF、Esc/Ctrl系は安全側で維持)。**迷ったら「加工しない」に倒す**
- **候補ポップアップ(@メンション等)のEnter素通し**: 入力欄で `@` `#` `:` `/` を打つと候補リストが出てEnterで確定する。このEnterをShift+Enterにすると候補が選ばれず改行になるため、「候補が開いていそう」な間の素のEnterだけ無加工で通す(RemapEngine.isSuggesting)。ポップアップの有無はAXで取れないのでキーシーケンス推定: トリガー文字はCGEventのUnicode文字列で判定(`@`/`#`は単語頭、`:`は単語頭+2文字以上、`/`は行頭。英数モードで打ったものだけ)。Space/Esc/Tab/クリック/カーソル移動/Cmd・Ctrl系/トリガー削除で解除、↑↓と日本語の変換操作は維持(「英数で@→かなで名前→確定→Enter」が通る)。**誤判定すると素通しEnterが送信になるので、こちらは変換中推定と逆に「迷ったら改行」に倒す**。残るリスクは「候補が一致なしで自動的に閉じた直後のEnter」
- **ブラウザ判定(AXのみ・追加権限なし)**: SafariはAXWebAreaの`AXURL`、Chrome系はアドレスバーのAXValue、**ArcはアドレスバーがAXに存在しないため `commandBarPlaceholderTextField`(ドメインのみ)を読む**。ドメインのみの場合はパス条件を緩和(hostOnly)。アドレスバー編集中(フォーカスがブラウザUIのテキスト欄)は書き換え停止。AXObserver通知→専用キューで評価→結果をキャッシュ
- **アプリ側送信キーの宣言と自動検出**: Slack等は設定で送信キーを⌘Enterに反転でき、その場合⌘Enterの意味が逆転して書き換えが破綻する。LINEとSlackは設定ファイルから自動検出する(`SendKeyDetector`: LINEは `LINE.ini` の `chat_sendkey=1`、SlackはIndexedDB blobをSnappy伸長して `msg_input_send_btn`=true。どちらも非公開実装依存のベストエフォートで、読めない場合はunknownに倒す)。それ以外のアプリと検出失敗時は、設定の「詳細オプション」でユーザーに宣言してもらう(素通し判定は宣言∪検出)。**macOS 15+は他アプリのコンテナ初アクセスで許可ダイアログが出て、ユーザーが答えるまで `open()` がブロックしたままになる**(実機で確認済み)。そのため読み取りは専用の並列キューのみで行い、起動時ではなく**対象アプリを開いた直後**に走らせる(ダイアログに文脈を与える)。unknownに終わったら自動再試行しない(ダイアログの繰り返しを避ける)。やり直しは設定の「LINE・Slackの設定を読み直す」から
- **設定モデル**: `enabledDesktopIDs` / `enabledWebIDs`(サービス×面で独立、旧`enabledBundleIDs`+`browserSupportEnabled`から自動移行)。対象サービスはAppRegistryに集約(hasDesktop/hasWeb、aliases)
- **課金**: 買い切り+14日無料トライアル。トライアル開始日時はUserDefaults+Application Supportマーカーの二重記録(早い方採用、再インストール耐性)。ライセンスはEd25519署名キーのオフライン検証(公開鍵はLicenseManagerに埋め込み)。発行: `swift license-signing/issue.swift 購入者メール`。期限切れ時は書き換えのみ停止
- **購入受付前の表示**: `LicenseView.swift` の `purchaseOpen` が false の間は「購入について(Webサイト)」+準備中の注記を出す(LPも「購入は準備中」なので行き止まりを避ける)。受付開始時に true にする
- **メニューバー**: ステータス行 / 一時停止 / 設定… / 使い方… / ⌘Enterで送信できないとき… / ライセンス… / 終了。ステータス行は「止まっているのに動いて見える」を避けるため、許可切れ・トライアル終了・タップ停止のときは押して直せる項目になる。ブラウザ判定の診断はOptionキーを押して開いたときだけ出る
- **アプリの色**: `Assets.xcassets/AccentColor`(ライト #0f7b6c / ダーク #4fb3a3)をグローバルアクセントに設定済み。「→ 改行」は accentColor、「→ 送信」は primary。青・緑・オレンジの文字色は使わない(アイコンのみ可)
- **決済はPolar.sh予定**(Paddleはドメイン審査が進まず断念): 手順は `notes/POLAR-SETUP.md`、ユーザー作業の全体は `notes/PAYMENT-CHECKLIST.md`。チェックアウトURL確定後、LP価格セクションのボタンと `UniEnter/UI/LicenseView.swift` の `purchaseURL` を差し替える

## 画面スクリーンショット(修正指示・レビュー用)

`screenshots/app/` にアプリの全画面(9画面 × ライト/ダーク = 18枚)と `INDEX.md` が入っている。
**UIの現状を確認したいときは、アプリを起動せずここを見る。**

- 生成: `./scripts/screenshots.sh`。ファイル名は固定で毎回上書きされるため、常に最新
- 実装: `UniEnter/Debug/ScreenshotMode.swift`(DEBUGビルド限定)。
  `UniEnter.app --screenshot-mode <出力先>` で起動すると、常駐処理を始めずに各SwiftUIビューを
  オフスクリーン描画してPNGを保存し終了する。**画面収録権限も実機操作も不要**
- 撮影対象を増やす/減らすときは `allShots()` に追記する。ライセンス状態などは
  使い捨てのUserDefaults suiteと使い捨てEd25519鍵で作るので、実際の設定・ライセンスには影響しない
- 自動更新: `.claude/settings.json` の Stop フックが `scripts/screenshots-if-stale.sh` を呼ぶ。
  `UniEnter/UI/` などが `screenshots/app/INDEX.md` より新しいときだけ再生成する(通常は0.4秒で素通り)
- 落とし穴: 各ビューは背景色を持たない(ウィンドウ背景の上に置かれる前提)ため、
  **撮影時に外観ごとの `windowBackgroundColor` を明示的に敷かないとダークが「白地に白文字」になる**。
  取りこぼしに気付けるよう、ほぼ単色のPNGが出たら失敗する自己チェックを入れてある
- 撮れないもの: メニューバーのドロップダウン(NSMenuはOSが描画するため、この方式では取得不可)

## 公開状態(重要)

- **2026-07-22に公開済み**: リポジトリpublic・GitHub Pages有効。最新リリースはv0.3.2(2026-09-09、pkg+zip添付。LPのDLボタンは `releases/latest` 参照なので自動で最新になる)
- LP: https://unienter.oc-to.com/(利用規約 terms.html / プライバシーポリシー privacy.html も公開済み)
- リリース: https://github.com/iwai-ddndn/UniEnter/releases
- コミットメールはGitHub noreplyに統一済み(個人メールをコミットに入れない)。再リリース時は `scripts/release.sh` → `scripts/publish.sh`

## LP(site/)の約束事

- トーン: 紙の生成り地(#f7f6f2)× 墨(#1d1c19)× ティール1色。「安心」セクションだけ夜色(#161613)。ゲーミング感・ネオン・発光グラデは禁止。LP固有の色・アニメーションは `site/src/landing.css`(`.lpn` 配下)にまとめてある
- モーション: 見出しの1文字ずつの立ち上がり、スクロール連動(Before/Afterは sticky で5場面、はじめかたのレールが伸びる)、マーキー。`prefers-reduced-motion` では全停止する。**IntersectionObserver頼みの表示なのでBrowser pane非表示中は検証できない**
- **キーカラーはティール #0f7b6c の1色のみ**(アプリアイコンと同色。`index.css` の `--primary` / `--ring`)。使うのはCTA・リンク・「改行」ラベル・フォーカス・はじめかたの番号チップだけで、**画面占有5%以下**。見出しや大きな面には使わない。薄いティントが要るときは 地#e8f3f0 / 文字#0b5f54。**青 #2383e2 は全廃**(「送信」は墨色。改行と送信の弁別は⌘キーの有無が担う)
- メインメッセージ: 「Enterでのうっかり送信を防ぎます」。説明文は「チャットアプリ/AIアプリでEnter送信を防ぎ、全て⌘+Enterで送信に統一します。」。LPのH1・`<title>`・meta description・OGP/Twitter・`og.html`(→ `public/assets/og.png` を再撮影)・README で揃える
- セクション順: ヒーロー → Before/After → 対応サービス → 安心 → はじめかた(2分) → 価格 → FAQ(安心/使い方/購入の3群) → 最終CTA → フッター(「作っている人」セクションは廃止。はじめかたは縦タイムラインで全手順を展開、対応サービスは2列のマーキー。FAQの中身は `site/src/faq.tsx`)
- 2026-09-29に現行デザインへ全面刷新(旧デザインは git 履歴の `site/src/App.tsx` / `HeroDemo.tsx` を参照)
- ヒーローは `App.tsx` の `ChatPlayground`: チャット → AIエージェントの自動デモを交互に流し(上のタブで切替も可)、入力欄をクリックすると実際に打てる(Enter=改行、⌘Enter=送信、変換中のEnterは無視)。**主CTAはデモより上**に置いてファーストビューに入れる。比較検討用の `hero-lab.html` は本番未リンクの内部ページ
- Before/Afterは説明文(大きな1文)が主役でデモが従。デモの方が目立つと「何が起きているか分からない」とのFBがあった
- 画像は実物のスクリーンショットのみ(`screenshots/app/` からWebP化)。生成AI画像・ストック写真は置かない。すべて `loading="lazy"` + `rounded-lg border`
- はじめかたのmacOSダイアログ3枚は `site/public/assets/install/`(`gatekeeper.png` / `settings-security.png` / `auth.png`)。無いあいだは点線の枠にフォールバックする
- 対象サービスの表示は `brands.tsx` の `services` に集約(simple-icons+頭文字タイル)
- 価格: ¥1,480(税込・買い切り)表記。変更時はLPとPaddle両方を揃える
- 商標: 各社ロゴの扱いは慎重に(名称表記は可、公式ロゴは原則許諾必要)。フッターの商標帰属表記を消さない

## 残タスク(2026-07-25時点)

1. **公証(最優先・ユーザー作業)**: Apple Developer Program加入 → Developer ID署名+公証。
   **2026-07-25の先行テストで、macOS 15の2台がどちらもインストールできず脱落した**
   (macOS 15以降は右クリック→「開く」の回避策が廃止され、システム設定からの解除しかない)。
   LPに手順セクションを用意して緩和したが、これは対症療法。**公証前に広く告知しないこと**。
   詳細はObsidian Vaultの `30_Notes/UniEnter/UniEnter-先行テストFB分析（Claude版）.md`(同Fable版もあり)
2. **課金は2026-09-29に稼働開始**: Polar(組織 `oc-to`)のCheckout Link → Worker `https://unienter-license.oc-to.workers.dev`(`license-signing/worker/`)がキーを発行・表示。LPの価格欄に「購入する」、特商法表記 `tokushoho.html` 公開済み。
   アプリ側も `LicenseView.swift` の `purchaseOpen = true`(購入ボタン→Polarのチェックアウト)に切替済み。ユーザーに届くのは次のリリース(公証と同時のv0.3.4予定)。残り(任意): `POLAR_ACCESS_TOKEN`、購入者へのキーのメール送信(Resend)
3. リリース手順: `project.yml` の `CFBundleShortVersionString` を上げる → `scripts/release.sh X.Y.Z` → `gh release create vX.Y.Z dist/UniEnter.pkg dist/UniEnter.zip`(publish.shは既存リリースへの添付用)
4. アプリアイコンはフラット版(ティール地に白の↵、`design/app-icon/` がソース。再生成手順は同READMEを参照)に差し替え済み
5. Gemini公式MacアプリのbundleID確認(判明したらAppRegistry.aliasesへ)
6. Chatworkは対象から除外済み(ユーザーが未使用・検証不能のため)。復活させる場合は過去コミット参照
7. FBで要望が出た「設定画面のスクショ付き・軽い使い方ページ」は未着手(`screenshots/app/` の画像が使える)

## 連絡先・クレジット表記の統一

「制作: octo(oc-to.com)/ お問い合わせ: info@oc-to.com」。LPフッター・支援ページ・アプリ設定画面・README・Info.plist(NSHumanReadableCopyright)に反映済み。新しい画面を作るときも同じ形式で入れる。
