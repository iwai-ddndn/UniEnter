import Foundation
import ServiceManagement

/// UserDefaultsによる設定の永続化。設定項目は「対象アプリの有効/無効」と
/// 「ログイン時起動」のみに絞る。
final class SettingsStore {
    private let defaults = UserDefaults.standard
    private static let enabledBundleIDsKey = "enabledBundleIDs"

    /// 書き換えを有効にするbundle IDの集合。未設定なら全対象アプリが有効。
    var enabledBundleIDs: Set<String> {
        get {
            guard let stored = defaults.stringArray(forKey: Self.enabledBundleIDsKey) else {
                return AppRegistry.allBundleIDs
            }
            return Set(stored)
        }
        set {
            defaults.set(Array(newValue).sorted(), forKey: Self.enabledBundleIDsKey)
        }
    }

    private static let browserSupportKey = "browserSupportEnabled"

    /// ブラウザ(Safari/Chrome系)で対象サービスのWeb版を開いているときも書き換えるか。既定ON。
    var browserSupportEnabled: Bool {
        get { defaults.object(forKey: Self.browserSupportKey) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Self.browserSupportKey) }
    }

    var launchAtLogin: Bool {
        get { SMAppService.mainApp.status == .enabled }
        set {
            do {
                if newValue {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                // 失敗してもアプリの動作には影響しない(UI側で実状態を再読込する)
            }
        }
    }
}
