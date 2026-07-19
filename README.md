# UniEnter

チャットアプリごとにバラバラな「改行/送信」のEnterキー挙動を統一するmacOSメニューバー常駐アプリ。

**統一後の挙動: Enter = 改行、⌘Enter = 送信**

## 対象アプリ

| アプリ | bundle ID |
|---|---|
| Microsoft Teams(新) | `com.microsoft.teams2` |
| Microsoft Teams(classic) | `com.microsoft.teams` |
| Slack | `com.tinyspeck.slackmacgap` |
| Discord | `com.hnc.Discord` |
| LINE | `jp.naver.line.mac` |
| Chatwork | `com.electron.chatwork` |

対象アプリ以外ではイベントに一切干渉しない。各アプリは送信キーが既定値(Enter=送信)である前提。

## ビルド

要件: Xcode / [XcodeGen](https://github.com/yonaskolb/XcodeGen)(`brew install xcodegen`)

```bash
xcodegen generate
xcodebuild -project UniEnter.xcodeproj -scheme UniEnter -configuration Release -derivedDataPath build build
open build/Build/Products/Release/UniEnter.app
```

テスト:

```bash
xcodebuild -project UniEnter.xcodeproj -scheme UniEnter -configuration Debug -derivedDataPath build test
```

初回起動時にアクセシビリティ許可の誘導画面が出る。許可すると自動で動作を開始する。

> **開発時の注意**: リビルドすると再署名によりアクセシビリティ許可が無効化され、イベントタップが黙って動かなくなることがある。その場合はシステム設定 > プライバシーとセキュリティ > アクセシビリティ で UniEnter を一度オフ→オンする。

## 仕組み

- `CGEventTap`(session level, head insert)でkeyDown/keyUp/leftMouseDownのみを監視。
  対象アプリが前面のときだけ、Enter(keycode 36/76)にShiftを付与(=改行)、⌘EnterからCmdを除去(=送信)する。
  書き換えは受信イベントのin-place改変(新規イベントのpostはしない)。
- タップが`kCGEventTapDisabledByTimeout`等で無効化されたら即時再有効化。スリープ復帰・セッション切替時にも確認する。

### 日本語IME対応(重要)

CGEventTapはIMEより手前でイベントを取得するため、変換確定のEnterを書き換えると入力が壊れる。
これを防ぐため、以下のいずれかに該当するEnterは**無加工でスルー**する:

1. IME等が合成したイベント(`eventSourceStateID != 1`)
2. 日本語入力モード(TIS APIで判定・キャッシュ)で「変換中」と推定される間

「変換中」はAX APIでは取得できない(Electron/ChromiumはmarkedRange系AX属性を実装していない)ため、
キーシーケンスから推定する: 文字生成キーの押下で変換中フラグON、確定Enter・左クリック・
入力ソース変更・アプリ切替・Cmd修飾キーでOFF。Escape/Backspace/Ctrl修飾キーでは
フラグを維持する(変換が続いている可能性があるため、安全側=加工しない側へ倒す)。

既知のリミテーション(いずれも安全側の挙動):

- Backspaceで未確定文字列を全削除した直後のEnterは素通し(=送信)になる
- 再変換などキー入力を経ずに始まる変換は検出できない(実害は確定時に改行が付く程度)

## 構成

```
UniEnter/
  App/            main.swift, AppDelegate.swift(配線・メニューバー)
  EventTap/       EventTapManager.swift(タップ管理)
                  RemapEngine.swift(書き換え判定の純粋ロジック、ユニットテスト対象)
  IME/            InputSourceMonitor.swift(TIS入力ソースのキャッシュ)
  Settings/       AppRegistry.swift(対象アプリ定義)、SettingsStore.swift(UserDefaults)
  UI/             SettingsView.swift(設定)、OnboardingView.swift(許可誘導)
UniEnterTests/    RemapEngineTests.swift(判定ロジックの網羅テスト)
```

`project.yml`(XcodeGen)がプロジェクト定義のソースオブトゥルース。`.xcodeproj`は生成物でありgit管理外。
