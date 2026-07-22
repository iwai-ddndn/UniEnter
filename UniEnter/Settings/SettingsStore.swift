import Foundation
import ServiceManagement

/// UserDefaultsによる設定の永続化。設定項目は「対象アプリの有効/無効」と
/// 「ログイン時起動」のみに絞る。
final class SettingsStore {
    private let defaults = UserDefaults.standard
    private static let enabledBundleIDsKey = "enabledBundleIDs" // 旧形式(移行元)
    private static let enabledDesktopIDsKey = "enabledDesktopIDs"
    private static let enabledWebIDsKey = "enabledWebIDs"

    /// デスクトップアプリで書き換えを有効にするサービスの集合。
    /// 未設定なら旧形式から移行し、それも無ければ全対象が有効。
    var enabledDesktopIDs: Set<String> {
        get {
            if let stored = defaults.stringArray(forKey: Self.enabledDesktopIDsKey) {
                return Set(stored)
            }
            if let legacy = defaults.stringArray(forKey: Self.enabledBundleIDsKey) {
                return Set(legacy).intersection(AppRegistry.desktopBundleIDs)
            }
            return AppRegistry.desktopBundleIDs
        }
        set {
            defaults.set(Array(newValue).sorted(), forKey: Self.enabledDesktopIDsKey)
        }
    }

    /// ブラウザ版で書き換えを有効にするサービスの集合。
    var enabledWebIDs: Set<String> {
        get {
            if let stored = defaults.stringArray(forKey: Self.enabledWebIDsKey) {
                return Set(stored)
            }
            if let legacy = defaults.stringArray(forKey: Self.enabledBundleIDsKey) {
                // 旧「ブラウザのWeb版でも有効」トグルを引き継ぐ
                return browserSupportEnabled ? Set(legacy).intersection(AppRegistry.webBundleIDs) : []
            }
            return AppRegistry.webBundleIDs
        }
        set {
            defaults.set(Array(newValue).sorted(), forKey: Self.enabledWebIDsKey)
        }
    }

    private static let hasSeenTutorialKey = "hasSeenTutorial"

    /// 初回チュートリアルを表示済みか
    var hasSeenTutorial: Bool {
        get { defaults.bool(forKey: Self.hasSeenTutorialKey) }
        set { defaults.set(newValue, forKey: Self.hasSeenTutorialKey) }
    }

    private static let cmdEnterSendAppsKey = "cmdEnterSendApps"

    /// アプリ側の設定で「送信キー=⌘Enter(Enterは改行)」になっているアプリの集合。
    /// これらは既に統一挙動(Enter=改行/⌘Enter=送信)なので書き換えを行わない。
    var cmdEnterSendApps: Set<String> {
        get { Set(defaults.stringArray(forKey: Self.cmdEnterSendAppsKey) ?? []) }
        set { defaults.set(Array(newValue).sorted(), forKey: Self.cmdEnterSendAppsKey) }
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
