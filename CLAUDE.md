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
- `marketing/` — リリース告知プランとX投稿用素材(公開リポジトリなので機密は置かない)
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
- **ブラウザ判定(AXのみ・追加権限なし)**: SafariはAXWebAreaの`AXURL`、Chrome系はアドレスバーのAXValue、**ArcはアドレスバーがAXに存在しないため `commandBarPlaceholderTextField`(ドメインのみ)を読む**。ドメインのみの場合はパス条件を緩和(hostOnly)。アドレスバー編集中(フォーカスがブラウザUIのテキスト欄)は書き換え停止。AXObserver通知→専用キューで評価→結果をキャッシュ
- **アプリ側送信キーの宣言と自動検出**: Slack等は設定で送信キーを⌘Enterに反転でき、その場合⌘Enterの意味が逆転して書き換えが破綻する。LINEとSlackは設定ファイルから自動検出する(`SendKeyDetector`: LINEは `LINE.ini` の `chat_sendkey=1`、SlackはIndexedDB blobをSnappy伸長して `msg_input_send_btn`=true。どちらも非公開実装依存のベストエフォートで、読めない場合はunknownに倒す)。それ以外のアプリと検出失敗時は、設定の「詳細オプション」でユーザーに宣言してもらう(素通し判定は宣言∪検出)。**macOS 15+は他アプリのコンテナ初アクセスで許可ダイアログが出て、ユーザーが答えるまで `open()` がブロックしたままになる**(実機で確認済み)。そのため読み取りは専用の並列キューのみで行い、起動時ではなく**対象アプリを開いた直後**に走らせる(ダイアログに文脈を与える)。unknownに終わったら自動再試行しない(ダイアログの繰り返しを避ける)。やり直しは設定の「LINE・Slackの設定を読み直す」から
- **設定モデル**: `enabledDesktopIDs` / `enabledWebIDs`(サービス×面で独立、旧`enabledBundleIDs`+`browserSupportEnabled`から自動移行)。対象サービスはAppRegistryに集約(hasDesktop/hasWeb、aliases)
- **課金**: 買い切り+14日無料トライアル。トライアル開始日時はUserDefaults+Application Supportマーカーの二重記録(早い方採用、再インストール耐性)。ライセンスはEd25519署名キーのオフライン検証(公開鍵はLicenseManagerに埋め込み)。発行: `swift license-signing/issue.swift 購入者メール`。期限切れ時は書き換えのみ停止
- **決済はPaddle予定**: 手順は `notes/PADDLE-SETUP.md`。チェックアウトURL確定後、LP価格セクションのボタンと `UniEnter/UI/LicenseView.swift` の `purchaseURL` を差し替える

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

- **2026-07-22に公開済み**: リポジトリpublic・GitHub Pages有効。最新リリースはv0.3.0(2026-09-08、pkg+zip添付。LPのDLボタンは `releases/latest` 参照なので自動で最新になる)
- LP: https://unienter.oc-to.com/(利用規約 terms.html / プライバシーポリシー privacy.html も公開済み)
- リリース: https://github.com/iwai-ddndn/UniEnter/releases
- コミットメールはGitHub noreplyに統一済み(個人メールをコミットに入れない)。再リリース時は `scripts/release.sh` → `scripts/publish.sh`

## LP(site/)の約束事

- トーン: ライト・Notion風(白背景、墨色#37352f、アクセントは改行=#0f7b6c/送信=#2383e2のみ)。ゲーミング感・ネオンは禁止
- ヒーローは `HeroDemo.tsx`(3アプリ同期タイピングデモ+キー押下)。比較検討用の `hero-lab.html` は本番未リンクの内部ページ
- 対象サービスの表示は `brands.tsx` の `services` に集約(simple-icons+頭文字タイル)
- 価格: ¥1,480(税込・買い切り)表記。変更時はLPとPaddle両方を揃える
- 商標: 各社ロゴの扱いは慎重に(名称表記は可、公式ロゴは原則許諾必要)。フッターの商標帰属表記を消さない

## 残タスク(2026-07-25時点)

1. **公証(最優先・ユーザー作業)**: Apple Developer Program加入 → Developer ID署名+公証。
   **2026-07-25の先行テストで、macOS 15の2台がどちらもインストールできず脱落した**
   (macOS 15以降は右クリック→「開く」の回避策が廃止され、システム設定からの解除しかない)。
   LPに手順セクションを用意して緩和したが、これは対症療法。**公証前に広く告知しないこと**。
   詳細はObsidian Vaultの `30_Notes/UniEnter/UniEnter-先行テストFB分析（Claude版）.md`(同Fable版もあり)
2. Paddleアカウント・商品・チェックアウトURL(ユーザー作業)→ 購入ボタン有効化
   - キー自動発行のCloudflare Workerは `license-signing/worker/` に実装済み(署名互換をCryptoKitで検証済み)。Paddleアカウント作成後に `worker/README.md` の手順でデプロイ
3. リリース手順: `project.yml` の `CFBundleShortVersionString` を上げる → `scripts/release.sh X.Y.Z` → `gh release create vX.Y.Z dist/UniEnter.pkg dist/UniEnter.zip`(publish.shは既存リリースへの添付用)
4. アプリアイコンはフラット版(ティール地に白の↵、`design/app-icon/` がソース。再生成手順は同READMEを参照)に差し替え済み
5. Gemini公式MacアプリのbundleID確認(判明したらAppRegistry.aliasesへ)
6. Chatworkは対象から除外済み(ユーザーが未使用・検証不能のため)。復活させる場合は過去コミット参照
7. FBで要望が出た「設定画面のスクショ付き・軽い使い方ページ」は未着手(`screenshots/app/` の画像が使える)

## 連絡先・クレジット表記の統一

「制作: octo(oc-to.com)/ お問い合わせ: info@oc-to.com」。LPフッター・支援ページ・アプリ設定画面・README・Info.plist(NSHumanReadableCopyright)に反映済み。新しい画面を作るときも同じ形式で入れる。
