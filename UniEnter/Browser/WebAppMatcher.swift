import Foundation

enum BrowserKind {
    case safari
    case chromium
}

enum BrowserRegistry {
    /// URL判定に対応するブラウザ。Firefoxは対象外(AXでURLを取得できない)。
    static let browsers: [String: BrowserKind] = [
        "com.apple.Safari": .safari,
        "com.apple.SafariTechnologyPreview": .safari,
        "com.google.Chrome": .chromium,
        "com.microsoft.edgemac": .chromium,
        "com.brave.Browser": .chromium,
        "com.vivaldi.Vivaldi": .chromium,
        "company.thebrowser.Browser": .chromium, // Arc
        "company.thebrowser.dia": .chromium,     // Dia
    ]
}

/// ブラウザのURLから「対象チャットサービスのWeb版か」を判定する純粋ロジック。
/// マッチしたら対応するデスクトップアプリのbundle IDを返し、設定の
/// アプリ別チェックボックスにそのまま連動させる。
enum WebAppMatcher {

    static func serviceBundleID(for url: URL) -> String? {
        guard let host = url.host?.lowercased() else { return nil }
        switch host {
        case "app.slack.com":
            // マーケティング(slack.com)やワークスペースのログインURL(*.slack.com)は含めない
            return "com.tinyspeck.slackmacgap"
        case "teams.cloud.microsoft", "teams.microsoft.com", "teams.live.com":
            return "com.microsoft.teams2"
        case "discord.com", "ptb.discord.com", "canary.discord.com":
            // discord.com ルートはマーケティングサイトのためパスで判定
            return url.path.hasPrefix("/channels") ? "com.hnc.Discord" : nil
        case "www.chatwork.com":
            // チャット画面は #!rid{数字}。ログインページ等でフォーム送信のEnterを壊さない
            return (url.fragment?.hasPrefix("!rid") ?? false) ? "com.electron.chatwork" : nil
        default:
            return nil
        }
    }

    /// アドレスバー(omnibox)の文字列をURLへ正規化する。
    /// Chromeはスキームを省略して表示するため https:// を補完する。
    /// 検索語などURLでないものはnil(=判定不能として書き換えない側に倒す)。
    static func normalizedURL(from text: String) -> URL? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.contains(" ") else { return nil }
        let withScheme = trimmed.contains("://") ? trimmed : "https://" + trimmed
        guard let url = URL(string: withScheme), let host = url.host, host.contains(".") else { return nil }
        return url
    }
}
