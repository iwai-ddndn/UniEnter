# UniEnter 画面一覧(自動生成)

`scripts/screenshots.sh` で生成。**このファイルと配下のPNGは手で編集しない**
(実行のたびに同じファイル名で上書きされる = 常に最新)。

全 18 枚。撮影対象を増やす場合は `UniEnter/Debug/ScreenshotMode.swift` の
`allShots()` に追記する。

> メニューバーのドロップダウン(NSMenu)はOSが描画するため、この方式では撮影できない。

| 画面 | ライト | ダーク |
| --- | --- | --- |
| オンボーディング(アクセシビリティ許可の誘導) | ![](01-onboarding-light.png) | ![](01-onboarding-dark.png) |
| オンボーディング(10秒経過後に出るトラブルシューティング付き) | ![](02-onboarding-troubleshooting-light.png) | ![](02-onboarding-troubleshooting-dark.png) |
| チュートリアル 1/2 — 覚えるのは2つだけ | ![](03-tutorial-1-keys-light.png) | ![](03-tutorial-1-keys-dark.png) |
| チュートリアル 2/2 — ⌘Enter送信済みアプリの確認(Slackは自動検出の例) | ![](04-tutorial-2-sendkey-light.png) | ![](04-tutorial-2-sendkey-dark.png) |
| 設定(既定状態) | ![](05-settings-light.png) | ![](05-settings-dark.png) |
| 設定(詳細オプション: アプリ側の送信キー を展開、Slackは自動検出の例) | ![](06-settings-advanced-light.png) | ![](06-settings-advanced-dark.png) |
| ライセンス(トライアル中・残り11日) | ![](07-license-trial-light.png) | ![](07-license-trial-dark.png) |
| ライセンス(トライアル終了・書き換え停止中) | ![](08-license-expired-light.png) | ![](08-license-expired-dark.png) |
| ライセンス(認証済み) | ![](09-license-activated-light.png) | ![](09-license-activated-dark.png) |