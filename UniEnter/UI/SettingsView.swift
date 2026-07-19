import SwiftUI

final class SettingsViewModel: ObservableObject {
    @Published var enabledBundleIDs: Set<String>
    @Published var launchAtLogin: Bool

    private let store: SettingsStore
    /// 有効アプリ集合が変わったときにAppDelegateへ伝える
    var onEnabledAppsChange: ((Set<String>) -> Void)?

    init(store: SettingsStore) {
        self.store = store
        self.enabledBundleIDs = store.enabledBundleIDs
        self.launchAtLogin = store.launchAtLogin
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
                    Toggle(app.name, isOn: model.isEnabled(app))
                }
            }
            .padding(.leading, 4)

            Divider()

            Toggle("ログイン時に起動", isOn: Binding(
                get: { model.launchAtLogin },
                set: { model.setLaunchAtLogin($0) }
            ))
        }
        .padding(20)
        .frame(width: 320)
    }
}
