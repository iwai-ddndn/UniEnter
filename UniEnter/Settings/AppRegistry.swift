import Foundation

struct TargetApp {
    let name: String
    let bundleID: String
}

enum AppRegistry {
    /// 対象チャットアプリ。前面アプリのbundle IDがここに含まれる場合のみキーを書き換える。
    static let all: [TargetApp] = [
        TargetApp(name: "Microsoft Teams", bundleID: "com.microsoft.teams2"),
        TargetApp(name: "Microsoft Teams (classic)", bundleID: "com.microsoft.teams"),
        TargetApp(name: "Slack", bundleID: "com.tinyspeck.slackmacgap"),
        TargetApp(name: "Discord", bundleID: "com.hnc.Discord"),
        TargetApp(name: "LINE", bundleID: "jp.naver.line.mac"),
        // Electronビルダー既定の接頭辞をそのまま使っている(com.chatwork.* ではない)
        TargetApp(name: "Chatwork", bundleID: "com.electron.chatwork"),
    ]

    static let allBundleIDs: Set<String> = Set(all.map(\.bundleID))
}
