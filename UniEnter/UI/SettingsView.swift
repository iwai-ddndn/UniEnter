import SwiftUI

final class SettingsViewModel: ObservableObject {
    @Published var enabledDesktopIDs: Set<String>
    @Published var enabledWebIDs: Set<String>
    @Published var launchAtLogin: Bool
    @Published var cmdEnterSendApps: Set<String>

    private let store: SettingsStore
    var onDesktopIDsChange: ((Set<String>) -> Void)?
    var onWebIDsChange: ((Set<String>) -> Void)?
    var onCmdEnterSendAppsChange: ((Set<String>) -> Void)?

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
    @State private var showAdvanced = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("対象アプリ")
                .font(.headline)
            Text("チェックしたところで Enter=改行、⌘Enter=送信 に統一します。")
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

            Divider()

            DisclosureGroup(isExpanded: $showAdvanced) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("アプリ側の設定で送信キーを「⌘Enter」に変更している場合はここで宣言してください。そのアプリは既に統一挙動のため、書き換えを行いません。")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    ForEach(AppRegistry.all.filter(\.hasDesktop), id: \.bundleID) { app in
                        HStack {
                            Text(app.name)
                            Spacer()
                            Picker("", selection: model.sendKey(app)) {
                                Text("Enter").tag("Enter")
                                Text("⌘Enter").tag("⌘Enter")
                            }
                            .labelsHidden()
                            .fixedSize()
                        }
                    }
                }
                .padding(.top, 6)
            } label: {
                Text("詳細オプション: アプリ側の送信キー")
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
