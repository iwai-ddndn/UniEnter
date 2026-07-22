import Foundation

struct TargetApp {
    let name: String
    let bundleID: String
    /// デスクトップアプリが存在するか(前面アプリ判定の対象になるか)
    var hasDesktop = true
    /// ブラウザ版が存在するか(URL判定の対象になるか)
    var hasWeb = true
}

enum AppRegistry {
    /// 対象チャットサービス。設定・判定はこのbundle ID(サービス代表ID)で行う。
    static let all: [TargetApp] = [
        TargetApp(name: "Microsoft Teams", bundleID: "com.microsoft.teams2"),
        TargetApp(name: "Microsoft Teams (classic)", bundleID: "com.microsoft.teams", hasWeb: false),
        TargetApp(name: "Slack", bundleID: "com.tinyspeck.slackmacgap"),
        TargetApp(name: "Discord", bundleID: "com.hnc.Discord"),
        TargetApp(name: "LINE", bundleID: "jp.naver.line.mac", hasWeb: false),
        // 2026年7月のCodex統合後の現行ChatGPT.app。旧ChatGPT Classicはaliasesで対応
        TargetApp(name: "ChatGPT", bundleID: "com.openai.codex"),
        TargetApp(name: "Claude", bundleID: "com.anthropic.claudefordesktop"),
        // Gemini公式Macアプリ(2026年4月〜)のbundle IDは未確認のため、当面は設定キー兼
        // Web判定の対応付けにのみ使う擬似ID。実IDが判明したらaliasesに追加する
        TargetApp(name: "Gemini", bundleID: "web.gemini.google.com", hasDesktop: false),
        // デスクトップアプリは2025年末に廃止済み(残存インストール向け)。主戦場はWeb判定
        TargetApp(name: "Messenger", bundleID: "com.facebook.archon"),
        // XとInstagramのDMはWeb専用(公式デスクトップアプリなし)。設定キー兼Web判定用の擬似ID
        TargetApp(name: "X(DM)", bundleID: "web.x.com", hasDesktop: false),
        TargetApp(name: "Instagram(DM)", bundleID: "web.instagram.com", hasDesktop: false),
    ]

    /// 同一サービスの別bundle IDを代表IDへ寄せる(設定・判定は代表IDで行う)
    static let aliases: [String: String] = [
        "com.openai.chat": "com.openai.codex",             // ChatGPT Classic
        "com.facebook.archon.developerID": "com.facebook.archon", // Messenger直接配布版
    ]

    static let allBundleIDs: Set<String> = Set(all.map(\.bundleID))
    static let desktopBundleIDs: Set<String> = Set(all.filter(\.hasDesktop).map(\.bundleID))
    static let webBundleIDs: Set<String> = Set(all.filter(\.hasWeb).map(\.bundleID))

    /// aliasを解決した代表bundle IDを返す
    static func canonicalBundleID(_ bundleID: String) -> String {
        aliases[bundleID] ?? bundleID
    }
}
