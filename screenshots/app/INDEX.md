# UniEnter 画面一覧(自動生成)

`scripts/screenshots.sh` で生成。**このファイルと配下のPNGは手で編集しない**
(実行のたびに同じファイル名で上書きされる = 常に最新)。

全 20 枚。撮影対象を増やす場合は `UniEnter/Debug/ScreenshotMode.swift` の
`allShots()` に追記する。

> メニューバーのドロップダウン(NSMenu)はOSが描画するため、この方式では撮影できない。

| 画面 | ライト | ダーク |
| --- | --- | --- |
| オンボーディング(アクセシビリティ許可の誘導) | ![](01-onboarding-light.png) | ![](01-onboarding-dark.png) |
| オンボーディング(10秒経過後に出るトラブルシューティング付き) | ![](02-onboarding-troubleshooting-light.png) | ![](02-onboarding-troubleshooting-dark.png) |
| チュートリアル 1/3 — 覚えるのは2つだけ | ![](03-tutorial-1-keys-light.png) | ![](03-tutorial-1-keys-dark.png) |
| チュートリアル 2/3 — 対象アプリ | ![](04-tutorial-2-apps-light.png) | ![](04-tutorial-2-apps-dark.png) |
| チュートリアル 3/3 — 日本語入力の安全性 | ![](05-tutorial-3-safety-light.png) | ![](05-tutorial-3-safety-dark.png) |
| 設定(既定状態) | ![](06-settings-light.png) | ![](06-settings-dark.png) |
| 設定(詳細オプション: アプリ側の送信キー を展開) | ![](07-settings-advanced-light.png) | ![](07-settings-advanced-dark.png) |
| ライセンス(トライアル中・残り11日) | ![](08-license-trial-light.png) | ![](08-license-trial-dark.png) |
| ライセンス(トライアル終了・書き換え停止中) | ![](09-license-expired-light.png) | ![](09-license-expired-dark.png) |
| ライセンス(認証済み) | ![](10-license-activated-light.png) | ![](10-license-activated-dark.png) |