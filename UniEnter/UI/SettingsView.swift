import SwiftUI

final class SettingsViewModel: ObservableObject {
    @Published var enabledBundleIDs: Set<String>
    @Published var launchAtLogin: Bool
    @Published var browserSupport: Bool
    @Published var cmdEnterSendApps: Set<String>

    private let store: SettingsStore
    /// 有効アプリ集合が変わったときにAppDelegateへ伝える
    var onEnabledAppsChange: ((Set<String>) -> Void)?
    var onBrowserSupportChange: ((Bool) -> Void)?
    var onCmdEnterSendAppsChange: ((Set<String>) -> Void)?

    init(store: SettingsStore) {
        self.store = store
        self.enabledBundleIDs = store.enabledBundleIDs
        self.launchAtLogin = store.launchAtLogin
        self.browserSupport = store.browserSupportEnabled
        self.cmdEnterSendApps = store.cmdEnterSendApps
    }

    func isEnabled(_ app: TargetApp) -> Binding<Bool> {
        Binding(
            get: { self.enabledBundleIDs.contains(app.bundleID) },
            set: { enabled in
                if enabled {
                    self.enabledBundleIDs.insert(app.bundleID)
                } else {
                    self.enabledBundleIDs.remove(app.bundleID)
                }
                self.store.enabledBundleIDs = self.enabledBundleIDs
                self.onEnabledAppsChange?(self.enabledBundleIDs)
            }
        )
    }

    func setLaunchAtLogin(_ value: Bool) {
        store.launchAtLogin = value
        // 登録に失敗した場合に備えて実状態を読み直す
        launchAtLogin = store.launchAtLogin
    }

    func setBrowserSupport(_ value: Bool) {
        browserSupport = value
        store.browserSupportEnabled = value
        onBrowserSupportChange?(value)
    }

    /// アプリ側の送信キー("Enter" or "⌘Enter")のバインディング
    func sendKey(_ app: TargetApp) -> Binding<String> {
        Binding(
            get: { self.cmdEnterSendApps.contains(app.bundleID) ? "⌘Enter" : "Enter" },
            set: { value in
                if value == "⌘Enter" {
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

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("対象アプリ")
                .font(.headline)
            Text("チェックしたアプリで Enter=改行、⌘Enter=送信 に統一します。")
                .font(.caption)
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 6) {
                ForEach(AppRegistry.all, id: \.bundleID) { app in
                    HStack {
                        Toggle(app.name, isOn: model.isEnabled(app))
                        Spacer()
                        Picker("", selection: model.sendKey(app)) {
                            Text("Enter").tag("Enter")
                            Text("⌘Enter").tag("⌘Enter")
                        }
                        .labelsHidden()
                        .fixedSize()
                        .disabled(!model.enabledBundleIDs.contains(app.bundleID))
                    }
                }
            }
            .padding(.leading, 4)

            Text("右はアプリ側で設定している送信キー。アプリ側を「⌘Enterで送信(Enterで改行)」にしている場合は ⌘Enter を選ぶと、そのアプリでは書き換えを行いません(既に Enter=改行/⌘Enter=送信 のため)。")
                .font(.caption)
                .foregroundColor(.secondary)

            Divider()

            Toggle("ブラウザのWeb版でも有効", isOn: Binding(
                get: { model.browserSupport },
                set: { model.setBrowserSupport($0) }
            ))
            Text("Safari/Chrome系で各サービスのWeb版(app.slack.com など)を開いているタブでも統一します。LINEとFirefoxは非対応。")
                .font(.caption)
                .foregroundColor(.secondary)

            Toggle("ログイン時に起動", isOn: Binding(
                get: { model.launchAtLogin },
                set: { model.setLaunchAtLogin($0) }
            ))

            Divider()

            Text("制作: octo — [info@oc-to.com](mailto:info@oc-to.com)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(20)
        .frame(width: 320)
    }
}
