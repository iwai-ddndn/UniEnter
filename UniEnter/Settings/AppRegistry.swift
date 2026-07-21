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
        // 2026年7月のCodex統合後の現行ChatGPT.app。旧ChatGPT Classicはaliasesで対応
        TargetApp(name: "ChatGPT", bundleID: "com.openai.codex"),
        TargetApp(name: "Claude", bundleID: "com.anthropic.claudefordesktop"),
        // Gemini公式Macアプリ(2026年4月〜)のbundle IDは未確認のため、当面は設定キー兼
        // Web判定の対応付けにのみ使う擬似ID。実IDが判明したらaliasesに追加する
        TargetApp(name: "Gemini", bundleID: "web.gemini.google.com"),
        // デスクトップアプリは2025年末に廃止済み(残存インストール向け)。主戦場はWeb判定
        TargetApp(name: "Messenger", bundleID: "com.facebook.archon"),
    ]

    /// 同一サービスの別bundle IDを代表IDへ寄せる(設定・判定は代表IDで行う)
    static let aliases: [String: String] = [
        "com.openai.chat": "com.openai.codex",             // ChatGPT Classic
        "com.facebook.archon.developerID": "com.facebook.archon", // Messenger直接配布版
    ]

    static let allBundleIDs: Set<String> = Set(all.map(\.bundleID))

    /// aliasを解決した代表bundle IDを返す
    static func canonicalBundleID(_ bundleID: String) -> String {
        aliases[bundleID] ?? bundleID
    }
}
