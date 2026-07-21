import XCTest
@testable import UniEnter

final class WebAppMatcherTests: XCTestCase {

    private func match(_ urlString: String) -> String? {
        guard let url = URL(string: urlString) else { return nil }
        return WebAppMatcher.serviceBundleID(for: url)
    }

    // MARK: - Slack

    func testSlackWebClientMatches() {
        XCTAssertEqual(match("https://app.slack.com/client/T012345/C012345"),
                       "com.tinyspeck.slackmacgap")
    }

    func testSlackMarketingAndWorkspaceURLsDoNotMatch() {
        XCTAssertNil(match("https://slack.com/intl/ja-jp/"))
        XCTAssertNil(match("https://myworkspace.slack.com/signin"))
    }

    // MARK: - Teams

    func testTeamsHostsMatch() {
        XCTAssertEqual(match("https://teams.cloud.microsoft/v2/"), "com.microsoft.teams2")
        XCTAssertEqual(match("https://teams.microsoft.com/_"), "com.microsoft.teams2")
        XCTAssertEqual(match("https://teams.live.com/v2/"), "com.microsoft.teams2")
    }

    func testTeamsMarketingDoesNotMatch() {
        XCTAssertNil(match("https://www.microsoft.com/ja-jp/microsoft-teams/group-chat-software"))
    }

    // MARK: - Discord

    func testDiscordChannelsMatch() {
        XCTAssertEqual(match("https://discord.com/channels/@me"), "com.hnc.Discord")
        XCTAssertEqual(match("https://canary.discord.com/channels/123/456"), "com.hnc.Discord")
        XCTAssertEqual(match("https://ptb.discord.com/channels/123/456"), "com.hnc.Discord")
    }

    func testDiscordMarketingDoesNotMatch() {
        XCTAssertNil(match("https://discord.com/"))
        XCTAssertNil(match("https://discord.com/download"))
    }

    // MARK: - Chatwork

    func testChatworkChatScreenMatches() {
        XCTAssertEqual(match("https://www.chatwork.com/#!rid12345"), "com.electron.chatwork")
    }

    func testChatworkLoginAndMarketingDoNotMatch() {
        XCTAssertNil(match("https://www.chatwork.com/login.php"))
        XCTAssertNil(match("https://go.chatwork.com/ja/"))
    }

    // MARK: - AIチャット・Messenger

    func testAIChatServicesMatch() {
        XCTAssertEqual(match("https://chatgpt.com/c/12345"), "com.openai.codex")
        XCTAssertEqual(match("https://chat.openai.com/"), "com.openai.codex")
        XCTAssertEqual(match("https://claude.ai/new"), "com.anthropic.claudefordesktop")
        XCTAssertEqual(match("https://gemini.google.com/app"), "web.gemini.google.com")
    }

    func testMessengerMatches() {
        XCTAssertEqual(match("https://www.messenger.com/t/12345"), "com.facebook.archon")
        XCTAssertEqual(match("https://www.facebook.com/messages/t/12345"), "com.facebook.archon")
    }

    func testAIMarketingSitesDoNotMatch() {
        XCTAssertNil(match("https://openai.com/chatgpt"))
        XCTAssertNil(match("https://www.anthropic.com/claude"))
        XCTAssertNil(match("https://www.facebook.com/"))
    }

    func testFacebookHostOnlyDoesNotMatch() {
        // Arc等のドメインのみ取得ではfacebook.com全域を対象にしない
        let url = URL(string: "https://www.facebook.com/")!
        XCTAssertNil(WebAppMatcher.serviceBundleID(for: url, hostOnly: true))
    }

    // MARK: - その他

    func testUnrelatedSitesDoNotMatch() {
        XCTAssertNil(match("https://www.google.com/search?q=slack"))
        XCTAssertNil(match("https://example.com/"))
    }

    func testHostMatchingIsCaseInsensitive() {
        XCTAssertEqual(match("https://APP.SLACK.COM/client/T1/C1"), "com.tinyspeck.slackmacgap")
    }

    // MARK: - hostOnly(Arcのコマンドバー: ドメインのみ取得できるケース)

    func testHostOnlyRelaxesDiscordPathRequirement() {
        let url = URL(string: "https://discord.com/")!
        XCTAssertEqual(WebAppMatcher.serviceBundleID(for: url, hostOnly: true), "com.hnc.Discord")
        XCTAssertNil(WebAppMatcher.serviceBundleID(for: url, hostOnly: false))
    }

    func testHostOnlyRelaxesChatworkFragmentRequirement() {
        let url = URL(string: "https://www.chatwork.com/")!
        XCTAssertEqual(WebAppMatcher.serviceBundleID(for: url, hostOnly: true), "com.electron.chatwork")
        XCTAssertNil(WebAppMatcher.serviceBundleID(for: url, hostOnly: false))
    }

    func testHostOnlyStillRejectsUnrelatedHosts() {
        let url = URL(string: "https://slack.com/")!
        XCTAssertNil(WebAppMatcher.serviceBundleID(for: url, hostOnly: true))
    }

    func testArcCommandBarValueMatchesEndToEnd() {
        // Arcのコマンドバーはホスト名のみ(例: "app.slack.com")
        guard let url = WebAppMatcher.normalizedURL(from: "app.slack.com") else {
            return XCTFail("URL正規化に失敗")
        }
        XCTAssertEqual(WebAppMatcher.serviceBundleID(for: url, hostOnly: true), "com.tinyspeck.slackmacgap")
    }

    // MARK: - omnibox正規化

    func testNormalizedURLAddsScheme() {
        XCTAssertEqual(WebAppMatcher.normalizedURL(from: "app.slack.com/client/T1/C1")?.host,
                       "app.slack.com")
    }

    func testNormalizedURLKeepsExistingScheme() {
        XCTAssertEqual(WebAppMatcher.normalizedURL(from: "https://teams.cloud.microsoft/v2/")?.host,
                       "teams.cloud.microsoft")
    }

    func testNormalizedURLRejectsSearchText() {
        XCTAssertNil(WebAppMatcher.normalizedURL(from: "how to use app.slack.com"))
        XCTAssertNil(WebAppMatcher.normalizedURL(from: "slackとは"))
        XCTAssertNil(WebAppMatcher.normalizedURL(from: ""))
    }

    func testNormalizedOmniboxValueMatchesEndToEnd() {
        // Chromeのomniboxはスキーム省略表示になる
        guard let url = WebAppMatcher.normalizedURL(from: "discord.com/channels/@me") else {
            return XCTFail("URL正規化に失敗")
        }
        XCTAssertEqual(WebAppMatcher.serviceBundleID(for: url), "com.hnc.Discord")
    }
}
