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

    /// - Parameter hostOnly: URLの取得元がホスト名しか持たない場合(Arcのコマンドバー等)は
    ///   true。パス/フラグメントでの絞り込みを緩和する。誤って緩く判定しても結果は
    ///   「Enter=改行」側なので誤送信方向には倒れない。
    static func serviceBundleID(for url: URL, hostOnly: Bool = false) -> String? {
        guard let host = url.host?.lowercased() else { return nil }
        switch host {
        case "app.slack.com":
            // マーケティング(slack.com)やワークスペースのログインURL(*.slack.com)は含めない
            return "com.tinyspeck.slackmacgap"
        case "teams.cloud.microsoft", "teams.microsoft.com", "teams.live.com":
            return "com.microsoft.teams2"
        case "discord.com", "ptb.discord.com", "canary.discord.com":
            // discord.com ルートはマーケティングサイトのためパスで判定
            if hostOnly { return "com.hnc.Discord" }
            return url.path.hasPrefix("/channels") ? "com.hnc.Discord" : nil
        case "chatgpt.com", "chat.openai.com":
            // マーケティングは openai.com 側
            return "com.openai.codex"
        case "claude.ai":
            // マーケティングは claude.com / anthropic.com 側
            return "com.anthropic.claudefordesktop"
        case "gemini.google.com":
            return "web.gemini.google.com"
        case "www.messenger.com", "messenger.com":
            return "com.facebook.archon"
        case "www.facebook.com", "facebook.com":
            // messenger.com閉鎖後の本体。メッセージ画面のパスに限定(コメント欄等に干渉しない)
            if hostOnly { return nil }
            return url.path.hasPrefix("/messages") ? "com.facebook.archon" : nil
        case "x.com", "www.x.com", "twitter.com", "www.twitter.com":
            // DMのみ対象(ポスト作成欄は元々Enter=改行なので触らない)
            if hostOnly { return nil }
            return url.path.hasPrefix("/messages") ? "web.x.com" : nil
        case "www.instagram.com", "instagram.com":
            // DMのみ対象(コメント欄等に干渉しない)
            if hostOnly { return nil }
            return url.path.hasPrefix("/direct") ? "web.instagram.com" : nil
        default:
            return nil
        }
    }

    /// Follow only the focused element's parent chain, never sibling web areas.
    /// Generic so real observed AX structures can be replayed without UI permission.
    static func nearestFocusedWebArea<Node>(from start: Node,
                                            role: (Node) -> String?,
                                            parent: (Node) -> Node?) -> Node? {
        var current = start
        for _ in 0..<25 {
            if role(current) == "AXWebArea" { return current }
            guard let next = parent(current) else { return nil }
            current = next
        }
        return nil
    }

    /// サイドパネル向け: フォーカスされた複数行入力と、その最も近い
    /// WebAreaのHTTPS originが確認できる時だけGeminiを対象にする。
    /// ウィンドウ名・表示文字列・別タブのURLからは推測しない。
    static func focusedGeminiService(role: String?, subrole: String?, documentURL: URL?) -> String? {
        guard role == "AXTextArea", subrole != "AXSecureTextField",
              let url = documentURL, url.scheme?.lowercased() == "https",
              url.host?.lowercased() == "gemini.google.com",
              url.user == nil, url.password == nil,
              url.port == nil || url.port == 443 else { return nil }
        return "web.gemini.google.com"
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

/// Only fixed classifications are exportable. No page-controlled strings survive.
enum BrowserDiagnosticMetadata {
    static func line(role: String?, subrole: String?, url: URL?, focusedWindow: Bool) -> String {
        let roles: Set<String> = ["AXTextArea", "AXTextField", "AXSecureTextField", "AXWebArea",
            "AXGroup", "AXWindow", "AXApplication", "AXScrollArea", "AXSplitGroup",
            "AXToolbar", "AXButton", "AXSearchField", "AXComboBox"]
        let safeRole = role.flatMap { roles.contains($0) ? $0 : nil } ?? "other"
        let secure = role == "AXSecureTextField" || subrole == "AXSecureTextField"
        var origin = "unavailable"
        if !secure, let url {
            origin = "other"
            if url.scheme == "https", url.host == "gemini.google.com",
               url.user == nil, url.password == nil, url.port == nil || url.port == 443 {
                origin = "https://gemini.google.com"
            } else if url.scheme == "chrome", url.host == "glic" {
                origin = "chrome://glic"
            }
        }
        return "role=\(safeRole) secure=\(secure) origin=\(origin) focusedWindow=\(focusedWindow)"
    }
}

enum BrowserEvaluationReason: String {
    case timedOut, secureInput, missingFocusedURL, focusedGemini, rejectedGeminiInput
    case focusedWebService, otherFocusedWeb, browserTextInput, noWindow, noURL, tabService, otherTab
}
struct BrowserEvaluation {
    let service: String?
    let reason: BrowserEvaluationReason
    var metadata: String { "reason=\(reason.rawValue) gemini=\(service == "web.gemini.google.com")" }
}
struct BrowserDiagnosticRuntimeState {
    let tapRunning: Bool
    let entitled: Bool
    let geminiEnabled: Bool
    let remapperEnabled: Bool
    let targetActive: Bool
    let japanese: Bool
    let composing: Bool
    var metadata: String {
        "tapRunning=\(tapRunning) entitled=\(entitled) geminiEnabled=\(geminiEnabled) remapperEnabled=\(remapperEnabled) targetActive=\(targetActive) japanese=\(japanese) composing=\(composing)"
    }
}
