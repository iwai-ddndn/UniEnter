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

    // MARK: - X / Instagram (DMのみ)

    func testXDirectMessagesMatch() {
        XCTAssertEqual(match("https://x.com/messages/12345"), "web.x.com")
        XCTAssertEqual(match("https://twitter.com/messages"), "web.x.com")
    }

    func testXTimelineDoesNotMatch() {
        XCTAssertNil(match("https://x.com/home"))
        XCTAssertNil(match("https://x.com/compose/post"))
    }

    func testInstagramDirectMatches() {
        XCTAssertEqual(match("https://www.instagram.com/direct/t/12345"), "web.instagram.com")
    }

    func testInstagramFeedDoesNotMatch() {
        XCTAssertNil(match("https://www.instagram.com/"))
        XCTAssertNil(match("https://www.instagram.com/p/abc123/"))
    }

    func testChatworkNoLongerMatches() {
        XCTAssertNil(match("https://www.chatwork.com/#!rid12345"))
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

    func testHostOnlyDoesNotMatchPathGatedSocialHosts() {
        // XやInstagramはDMパスが確認できない限り対象にしない(Arc等のドメインのみ取得)
        XCTAssertNil(WebAppMatcher.serviceBundleID(for: URL(string: "https://x.com/")!, hostOnly: true))
        XCTAssertNil(WebAppMatcher.serviceBundleID(for: URL(string: "https://www.instagram.com/")!, hostOnly: true))
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

final class FocusedGeminiTests: XCTestCase {
    func testOnlyVerifiedGeminiMultilineInputMatches() {
        XCTAssertEqual(WebAppMatcher.focusedGeminiService(role: "AXTextArea", subrole: nil,
            documentURL: URL(string: "https://gemini.google.com/app")), "web.gemini.google.com")
        for raw in ["https://youtube.com/watch", "https://example.com/?gemini.google.com",
                    "https://gemini.google.com.evil.invalid/app", "http://gemini.google.com/app",
                    "chrome-extension://gemini.google.com/app", "https://accounts.google.com/",
                    "https://gemini.google.com:1234/app", "https://user@gemini.google.com/app"] {
            XCTAssertNil(WebAppMatcher.focusedGeminiService(role: "AXTextArea", subrole: nil,
                documentURL: URL(string: raw)), raw)
        }
    }
    func testUnverifiedFocusAndPasswordNeverMatch() {
        let url = URL(string: "https://gemini.google.com/app")
        for role in ["AXTextField", "AXSearchField", "AXButton", "AXWebArea", "AXGroup"] {
            XCTAssertNil(WebAppMatcher.focusedGeminiService(role: role, subrole: nil, documentURL: url))
        }
        XCTAssertNil(WebAppMatcher.focusedGeminiService(role: "AXTextArea", subrole: "AXSecureTextField", documentURL: url))
        XCTAssertNil(WebAppMatcher.focusedGeminiService(role: "AXTextArea", subrole: nil, documentURL: nil))
    }
}

final class BrowserDiagnosticPrivacyTests: XCTestCase {
    func testOnlyFixedMetadataCanBeExported() {
        let secret = "PRIVATE_CHAT_PASSWORD_LICENSE"
        for raw in ["https://gemini.google.com/\(secret)?token=\(secret)#\(secret)",
                    "https://\(secret)@example.invalid/\(secret)",
                    "chrome://glic/\(secret)?token=\(secret)",
                    "https://\(secret).example.invalid/"] {
            let line = BrowserDiagnosticMetadata.line(role: secret, subrole: secret,
                url: URL(string: raw), focusedWindow: true)
            XCTAssertFalse(line.contains(secret))
            XCTAssertFalse(line.contains("example.invalid"))
            XCTAssertTrue(line.contains("role=other"))
        }
    }
    func testSecureFieldSuppressesOrigin() {
        let line = BrowserDiagnosticMetadata.line(role: "AXTextField", subrole: "AXSecureTextField",
            url: URL(string: "https://gemini.google.com/glic"), focusedWindow: false)
        XCTAssertEqual(line,"role=AXTextField secure=true origin=unavailable focusedWindow=false")
    }
    func testGeminiAndInternalHostRemainDistinguishable() {
        for origin in ["https://gemini.google.com", "chrome://glic"] {
            let line = BrowserDiagnosticMetadata.line(role: "AXWebArea", subrole: nil,
                url: URL(string: origin + "/private?authuser=secret"), focusedWindow: false)
            XCTAssertTrue(line.contains("origin=" + origin + " "))
            XCTAssertFalse(line.contains("private"))
            XCTAssertFalse(line.contains("secret"))
        }
    }
}

/// Metadata observed 2026-10-07 01:46:20 UTC. No page text or full URLs.
final class ObservedChromeFocusTests: XCTestCase {
    private func nearest(_ roles: [String]) -> Int? {
        WebAppMatcher.nearestFocusedWebArea(from: 0, role: { roles[$0] },
            parent: { $0 + 1 < roles.count ? $0 + 1 : nil })
    }
    func testStandardGeminiPanelUsesGuestNotChromeHost() {
        // Samples 28–29: focused textarea, guest at depth 11, chrome://glic at 18.
        var roles = Array(repeating: "AXGroup", count: 25)
        roles[0] = "AXTextArea"; roles[11] = "AXWebArea"; roles[18] = "AXWebArea"
        let urls = [11: URL(string:"https://gemini.google.com")!, 18: URL(string:"chrome://glic")!]
        let document = nearest(roles)
        XCTAssertEqual(document,11)
        XCTAssertEqual(WebAppMatcher.focusedGeminiService(role:roles[0], subrole:nil,
            documentURL:document.flatMap { urls[$0] }), "web.gemini.google.com")
    }
    func testDeepAndShallowGeminiInputsRemainSupported() {
        for depth in [3,17] { // samples 24 and 25–27
            var roles=Array(repeating:"AXGroup",count:depth+1)
            roles[0]="AXTextArea"; roles[depth]="AXWebArea"
            XCTAssertEqual(nearest(roles),depth)
        }
    }
    func testObservedAddressBarCannotMatchGemini() {
        // Samples 15 and 17–20: toolbar ancestry, no web area.
        let roles=["AXTextField","AXGroup","AXToolbar","AXGroup","AXGroup","AXGroup","AXGroup","AXGroup","AXWindow","AXApplication"]
        XCTAssertNil(nearest(roles))
        XCTAssertNil(WebAppMatcher.focusedGeminiService(role:roles[0],subrole:nil,documentURL:nil))
    }
    func testOtherInnerDocumentCannotBorrowGeminiOuterOrigin() {
        let roles=["AXTextArea","AXGroup","AXWebArea","AXGroup","AXWebArea"]
        let urls=[2:URL(string:"https://example.invalid")!,4:URL(string:"https://gemini.google.com")!]
        let document=nearest(roles)
        XCTAssertEqual(document,2)
        XCTAssertNil(WebAppMatcher.focusedGeminiService(role:roles[0],subrole:nil,
            documentURL:document.flatMap { urls[$0] }))
    }
    func testCyclesAndMissingParentsStopWithinBound() {
        var calls=0
        let node: Int? = WebAppMatcher.nearestFocusedWebArea(from:0,role:{ _ in calls += 1;return "AXGroup" },parent:{ $0 })
        XCTAssertNil(node); XCTAssertEqual(calls,25)
        XCTAssertNil(nearest(["AXTextArea"]))
    }
}

final class RuntimeDiagnosticPrivacyTests: XCTestCase {
    func testEvaluationDoesNotExportArbitraryServiceText() {
        let result=BrowserEvaluation(service:"PRIVATE_CHAT_PASSWORD_LICENSE",reason:.otherFocusedWeb)
        XCTAssertEqual(result.metadata,"reason=otherFocusedWeb gemini=false")
        let state=BrowserDiagnosticRuntimeState(tapRunning:true,entitled:true,geminiEnabled:true,
            remapperEnabled:true,targetActive:false,japanese:true,composing:false)
        XCTAssertTrue(state.metadata.contains("targetActive=false"))
        XCTAssertFalse(state.metadata.contains("PRIVATE"))
    }
}

/// End-to-end pure replay of build11 focus-only metadata, not real key delivery.
final class Build11FocusPipelineTests: XCTestCase {
    func testObservedFocusSequenceThroughRemapEngine() {
        let enabled=AppRegistry.webBundleIDs
        let engine=RemapEngine()
        engine.isEnabled=true
        engine.inputSourceChanged(isJapanese:false)
        // 11:18:49 JST: panel textarea -> non-input web area -> textarea -> omnibox.
        let cases: [(String, Int?, Bool)] = [
            ("AXTextArea",11,true), ("AXWebArea",0,false),
            ("AXTextArea",17,true), ("AXTextField",nil,false)
        ]
        for (focusRole, documentDepth, expectedActive) in cases {
            var roles=Array(repeating:"AXGroup",count:25)
            roles[0]=focusRole
            if let depth=documentDepth { roles[depth]="AXWebArea" }
            else { roles[2]="AXToolbar" }
            let document=WebAppMatcher.nearestFocusedWebArea(from:0,role:{roles[$0]},
                parent:{$0+1<roles.count ? $0+1 : nil})
            let url=document.map { _ in URL(string:"https://gemini.google.com")! }
            let service=WebAppMatcher.focusedGeminiService(role:focusRole,subrole:nil,documentURL:url)
            let active=service.map { enabled.contains($0) } ?? false
            XCTAssertEqual(active,expectedActive)
            engine.frontmostChanged(isTarget:active)
            let expected: RemapAction = expectedActive ? .addShift : .passThrough
            XCTAssertEqual(engine.keyDown(keycode:36,mods:[],isPhysical:true),expected)
            XCTAssertEqual(engine.keyUp(keycode:36,mods:[]),expected)
        }
    }
}
