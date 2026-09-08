import SwiftUI

final class SettingsViewModel: ObservableObject {
    @Published var enabledDesktopIDs: Set<String>
    @Published var enabledWebIDs: Set<String>
    @Published var launchAtLogin: Bool
    @Published var cmdEnterSendApps: Set<String>
    /// アプリの設定ファイルから読み取った送信キー設定(AppDelegateが更新。保存はしない)。
    /// bundle IDごとのtri-state(.cmdEnterSend/.standard/.unknown・未検出はキー自体が無い)
    @Published var detectedSendKeys: [String: SendKeyDetection] = [:]

    /// Enterで改行(送信しない)の設定を自動検出できたアプリ。UniEnterは素通しする
    var detectedCmdEnterSendApps: Set<String> {
        Set(detectedSendKeys.filter { $0.value == .cmdEnterSend }.keys)
    }
    /// 「Enterで送信」の既定のままと自動検出できたアプリ。手動宣言があっても無視する
    var detectedStandardApps: Set<String> {
        Set(detectedSendKeys.filter { $0.value == .standard }.keys)
    }

    private let store: SettingsStore
    var onDesktopIDsChange: ((Set<String>) -> Void)?
    var onWebIDsChange: ((Set<String>) -> Void)?
    var onCmdEnterSendAppsChange: ((Set<String>) -> Void)?
    /// LINE/Slackの送信キー設定を読み直す(許可ダイアログを一度拒否した後のやり直し用)
    var onRecheckSendKeys: (() -> Void)?
    /// 「確認しにいく」でそのアプリを起動する(AppDelegateが配線。LINE/Slackは自動検出も走る)
    var openApp: ((String) -> Void)?
    /// そのアプリがインストールされているか(未配線ならインストール済み扱い)
    var isAppInstalled: ((String) -> Bool)?

    init(store: SettingsStore) {
        self.store = store
        self.enabledDesktopIDs = store.enabledDesktopIDs
        self.enabledWebIDs = store.enabledWebIDs
        self.launchAtLogin = store.launchAtLogin
        self.cmdEnterSendApps = store.cmdEnterSendApps
    }

    func desktopEnabled(_ app: TargetApp) -> Binding<Bool> {
        Binding(
            get: { self.enabledDesktopIDs.contains(app.bundleID) },
            set: { enabled in
                if enabled {
                    self.enabledDesktopIDs.insert(app.bundleID)
                } else {
                    self.enabledDesktopIDs.remove(app.bundleID)
                }
                self.store.enabledDesktopIDs = self.enabledDesktopIDs
                self.onDesktopIDsChange?(self.enabledDesktopIDs)
            }
        )
    }

    func webEnabled(_ app: TargetApp) -> Binding<Bool> {
        Binding(
            get: { self.enabledWebIDs.contains(app.bundleID) },
            set: { enabled in
                if enabled {
                    self.enabledWebIDs.insert(app.bundleID)
                } else {
                    self.enabledWebIDs.remove(app.bundleID)
                }
                self.store.enabledWebIDs = self.enabledWebIDs
                self.onWebIDsChange?(self.enabledWebIDs)
            }
        )
    }

    func setLaunchAtLogin(_ value: Bool) {
        store.launchAtLogin = value
        // 登録に失敗した場合に備えて実状態を読み直す
        launchAtLogin = store.launchAtLogin
    }

    /// そのアプリ自身の設定でEnter=改行(送信キー=⌘Enter)になっているか(＝UniEnterは手を出さない)
    func alreadyCmdEnter(_ app: TargetApp) -> Binding<Bool> {
        Binding(
            get: { self.cmdEnterSendApps.contains(app.bundleID) },
            set: { already in
                if already {
                    self.cmdEnterSendApps.insert(app.bundleID)
                } else {
                    self.cmdEnterSendApps.remove(app.bundleID)
                }
                self.store.cmdEnterSendApps = self.cmdEnterSendApps
                self.onCmdEnterSendAppsChange?(self.cmdEnterSendApps)
            }
        )
    }
}

struct SettingsView: View {
    @ObservedObject var model: SettingsViewModel
    @State private var showAdvanced: Bool

    init(model: SettingsViewModel, showAdvanced: Bool = false) {
        self.model = model
        _showAdvanced = State(initialValue: showAdvanced)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("対象アプリ")
                .font(.headline)
            Text("チェックを入れたところが、Enter=改行 / ⌘Enter=送信 になります。")
                .font(.caption)
                .foregroundColor(.secondary)

            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 5) {
                GridRow {
                    Text("")
                    Text("アプリ")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text("ブラウザ")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                ForEach(AppRegistry.all, id: \.bundleID) { app in
                    GridRow {
                        Text(app.name)
                            .gridColumnAlignment(.leading)
                        if app.hasDesktop {
                            Toggle("", isOn: model.desktopEnabled(app))
                                .labelsHidden()
                                .gridColumnAlignment(.center)
                        } else {
                            Text("—")
                                .foregroundColor(Color.secondary.opacity(0.5))
                                .gridColumnAlignment(.center)
                        }
                        if app.hasWeb {
                            Toggle("", isOn: model.webEnabled(app))
                                .labelsHidden()
                                .gridColumnAlignment(.center)
                        } else {
                            Text("—")
                                .foregroundColor(Color.secondary.opacity(0.5))
                                .gridColumnAlignment(.center)
                        }
                    }
                }
            }
            .padding(.leading, 4)

            Text("ブラウザ版はSafari / Chrome / Edge / Arcなどの対象タブで働きます。")
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Divider()

            // ここは「困ったときに自分で見つけられる」ことが最優先。
            // アプリ自身の設定でEnterが「改行」になっている人は、UniEnterと二重にかかって
            // 送信できなくなる。LINE/Slackは設定ファイルから自動検出できる(SendKeyDetector)が、
            // それ以外は外部から検知する手段がないため、症状から辿れる形にしてある。
            DisclosureGroup(isExpanded: $showAdvanced) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("そのアプリ自身の設定でEnterを「改行」に変えていると、UniEnterと二重にかかって送信できなくなります。⌘Enterで送信できるかどうかは関係ありません(既定のままでも⌘Enterで送れるアプリが多いです)。LINEとSlackは設定を自動で読み取って素通しします(「自動検出」表示)。その他のアプリは「その他のアプリを追加」からチェックを入れると、UniEnterはそのアプリに何もしません。")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("アプリ側で、Enterを改行に設定済み:")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.top, 2)

                    SendKeyAppListView(model: model)
                        .padding(.leading, 4)

                    if let recheck = model.onRecheckSendKeys {
                        Button("LINE・Slackの設定を読み直す", action: recheck)
                            .controlSize(.small)
                            .padding(.top, 2)
                        Text("読み取りにはmacOSの許可が必要です。ダイアログが出たら「許可」を選んでください(許可しなくても、上のチェックで手動指定できます)。")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.top, 6)
            } label: {
                Text("⌘Enterを押しても送信できないときは")
                    .font(.subheadline)
            }

            Divider()

            Toggle("ログイン時に起動", isOn: Binding(
                get: { model.launchAtLogin },
                set: { model.setLaunchAtLogin($0) }
            ))

            Divider()

            Text("制作: [octo](https://oc-to.com) — お問い合わせ: [info@oc-to.com](mailto:info@oc-to.com)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(20)
        .frame(width: 340)
    }
}
