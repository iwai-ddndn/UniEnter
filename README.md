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

対象アプリ以外ではイベントに一切干渉しない。

> **前提: 各アプリの送信設定に合わせて、UniEnter設定の「送信キー」列を選ぶこと。**
> アプリ側が既定(Enter=送信)なら「Enter」のまま。アプリ側を「⌘Enterで送信(Enterで改行)」に
> している場合は「⌘Enter」を選ぶ — そのアプリは既に統一挙動なので書き換えを止める。
> アプリ内部の設定は外部から検知できず、⌘Enterの意味がモードで反転するため、
> どちらのモードでも通用する単一の書き換えは存在しない(この宣言が必要な理由)。
> なおWeb版はワークスペース/アカウントごとに設定が独立しているため、この宣言は
> ネイティブアプリにのみ適用され、Web版は既定(Enter=送信)を前提とする。

### ブラウザのWeb版(既定で有効・設定でオフ可)

Safari / Chrome系(Chrome, Edge, Brave, Vivaldi, Arc, Dia)で以下のタブを開いているときも同じ統一が効く。
判定は対応するアプリのチェックボックスに連動する。

| サービス | 判定条件 |
|---|---|
| Slack | `app.slack.com` |
| Teams | `teams.cloud.microsoft` / `teams.microsoft.com` / `teams.live.com` |
| Discord | `discord.com`(ptb/canary含む)の `/channels` 配下 |
| Chatwork | `www.chatwork.com` の `#!rid…`(チャット画面のみ) |

LINEはWeb版が存在しないため対象外。FirefoxはAXでURLを取得できないため非対応。
アドレスバー編集中(そこでのEnterはナビゲーション)は書き換えを自動停止する。

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
- ブラウザ判定はAX APIのみで行う(追加権限なし)。SafariはAXWebAreaの`AXURL`、Chrome系は
  アドレスバー(omnibox)の`AXValue`を読む。`AXEnhancedUserInterface`はウィンドウ操作を壊す
  既知の副作用があるため使わない。タブ切替等はAXObserver通知で検知し、AX問い合わせは
  専用キューで非同期に行って結果だけをキャッシュする(タップコールバックからは呼ばない)。
  判定不能時は常に「書き換えない」。

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
  Browser/        WebAppMatcher.swift(Web版URL判定の純粋ロジック、ユニットテスト対象)
                  BrowserTabMonitor.swift(AXObserverによるタブ監視・非同期URL評価)
  IME/            InputSourceMonitor.swift(TIS入力ソースのキャッシュ)
  Settings/       AppRegistry.swift(対象アプリ定義)、SettingsStore.swift(UserDefaults)
  UI/             SettingsView.swift(設定)、OnboardingView.swift(許可誘導)
UniEnterTests/    RemapEngineTests.swift(判定ロジックの網羅テスト)
```

`project.yml`(XcodeGen)がプロジェクト定義のソースオブトゥルース。`.xcodeproj`は生成物でありgit管理外。
