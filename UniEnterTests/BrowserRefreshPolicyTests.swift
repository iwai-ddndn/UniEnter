import XCTest
@testable import UniEnter

final class BrowserRefreshPolicyTests: XCTestCase {
    func testNotificationBurstDoesNotPostponeFirstEvaluation() {
        var p = BrowserRefreshPolicy()
        p.setActive(true, now: 0)
        for t in [0.01, 0.03, 0.06, 0.079] { p.invalidate(now: t) }
        XCTAssertNotNil(p.begin(now: 0.081))
    }
    func testOnlyOneWorkerAndOldGenerationNeverPublishes() {
        var p = BrowserRefreshPolicy()
        p.setActive(true, now: 0)
        let old = p.begin(now: 0.1)!
        p.invalidate(now: 0.12)
        XCTAssertNil(p.begin(now: 20)) // blocked worker cannot create a backlog
        XCTAssertFalse(p.complete(old, now: 20))
        let next = p.begin(now: 20.01)!
        XCTAssertTrue(p.complete(next, now: 20.02))
        XCTAssertFalse(p.complete(old, now: 20.03))
    }
    func testMissingNotificationAfterDelayedInputCreationRecovers() {
        var p = BrowserRefreshPolicy()
        p.setActive(true, now: 0)
        var service: String?
        let first = p.begin(now: 0.1)!
        XCTAssertTrue(p.complete(first, now: 0.11)) // sidebar WebArea, not editable yet
        XCTAssertNil(service)
        // Input becomes AXTextArea at0.3; Chrome emits no further notification.
        let second = p.begin(now: 0.62)!
        let found = WebAppMatcher.focusedGeminiService(role: "AXTextArea", subrole: nil,
            documentURL: URL(string: "https://gemini.google.com/glic")!)
        if p.complete(second, now: 0.63) { service = found }
        XCTAssertEqual(service, "web.gemini.google.com")
    }
    func testTypingRestartsRecoveryAfterIdleWithoutNotification() {
        var p = BrowserRefreshPolicy()
        p.setActive(true, now: 0)
        let first = p.begin(now: 0.1)!
        XCTAssertTrue(p.complete(first, now: 2)) // budget exhausted or input not ready
        XCTAssertNil(p.begin(now: 100))
        p.activity(now: 100)
        let retry = p.begin(now: 100)!
        XCTAssertTrue(p.complete(retry, now: 100.1))
        XCTAssertNotNil(p.begin(now: 100.61))
    }
    func testIdleRecoveryStopsAndDoesNotPollForever() {
        var p = BrowserRefreshPolicy()
        p.setActive(true, now: 0)
        var starts = 0
        for step in 1...1000 {
            let now = Double(step) / 10
            if let ticket = p.begin(now: now) {
                starts += 1
                XCTAssertTrue(p.complete(ticket, now: now + 0.01))
            }
        }
        XCTAssertEqual(starts, 3)
    }
    func testSustainedActivityIsRateLimited() {
        var p = BrowserRefreshPolicy()
        p.setActive(true, now: 0)
        var times: [Double] = []
        for step in 1...10000 {
            let now = Double(step) / 1000
            p.activity(now: now)
            if let ticket = p.begin(now: now) {
                times.append(now)
                XCTAssertTrue(p.complete(ticket, now: now))
            }
        }
        XCTAssertLessThanOrEqual(times.count, 21) // <=2/s sustained typing
        for (a,b) in zip(times, times.dropFirst()) { XCTAssertGreaterThanOrEqual(b-a, 0.499) }
    }
    func testNotificationStormBoundedRateWithoutStarvation() {
        var p = BrowserRefreshPolicy()
        p.setActive(true, now: 0)
        var times: [Double] = []
        for step in 1...1000 {
            let now = Double(step) / 100
            p.invalidate(now: now)
            if let ticket = p.begin(now: now) {
                times.append(now)
                XCTAssertTrue(p.complete(ticket, now: now))
            }
        }
        XCTAssertGreaterThan(times.count, 30)
        XCTAssertLessThanOrEqual(times.count, 42) // two initial credits + four per second
        for i in times.indices {
            for j in i..<times.count {
                let capacity = BrowserRefreshPolicy.burstCapacity
                    + (times[j] - times[i]) * BrowserRefreshPolicy.evaluationsPerSecond
                XCTAssertLessThanOrEqual(Double(j - i + 1), capacity + 0.000001)
            }
        }
    }
    func testAppSwitchAndDisableDiscardInflightResult() {
        var p = BrowserRefreshPolicy()
        p.setActive(true, now: 0)
        let old = p.begin(now: 0.1)!
        p.setActive(false, now: 0.11)
        p.activity(now: 0.12)
        XCTAssertNil(p.begin(now: 1))
        p.setActive(true, now: 1)
        XCTAssertNil(p.begin(now: 1.1))
        XCTAssertFalse(p.complete(old, now: 1.2))
        XCTAssertNotNil(p.begin(now: 1.21))
    }
    func testRecoveryDoesNotBroadenGeminiInputMatcher() {
        for role in ["AXWebArea", "AXTextField", "AXGroup", "AXSecureTextField"] {
            XCTAssertNil(WebAppMatcher.focusedGeminiService(role: role, subrole: nil,
                documentURL: URL(string: "https://gemini.google.com/glic")!))
        }
        for url in ["https://example.com", "chrome://glic", "https://gemini.google.com.evil.test"] {
            XCTAssertNil(WebAppMatcher.focusedGeminiService(role: "AXTextArea", subrole: nil,
                documentURL: URL(string: url)!))
        }
    }
    func testPassiveTraceIsBoundedExpiresAndRecordsTypingOnlyOnce() {
        var trace = BrowserPassiveTrace()
        trace.start(now: 10)
        trace.record(.typingOccurred, now: 11)
        trace.record(.typingOccurred, now: 12)
        XCTAssertEqual(trace.lines.filter { $0.contains("event=typingOccurred") }.count, 1)
        for _ in 0..<1000 { trace.record(.focusNotification, now: 13) }
        XCTAssertTrue(trace.expired(now: 40))
        let lines = trace.finish(now: 40)
        XCTAssertEqual(lines.count, BrowserPassiveTrace.maximumLines)
        XCTAssertTrue(lines.last!.contains("typingOccurred=true capped=true"))
        trace.record(.evaluationStarted, now: 41)
        XCTAssertEqual(trace.lines, lines)
    }
    func testTraceKeepsLatestEvaluationAndTypingFlagAfterNotificationFlood() {
        var trace = BrowserPassiveTrace()
        trace.start(now: 0)
        for _ in 0..<1000 { trace.record(.otherNotification, now: 1) }
        trace.record(.typingOccurred, now: 2)
        trace.record(.evaluationFinished, now: 3, active: true, reason: .focusedGemini, accepted: true)
        let lines = trace.finish(now: 30)
        XCTAssertTrue(lines[lines.count - 2].contains("reason=focusedGemini accepted=true"))
        XCTAssertTrue(lines.last!.contains("typingOccurred=true capped=true"))
        XCTAssertEqual(lines.count, BrowserPassiveTrace.maximumLines)
    }
    func testTraceExpiresWithoutRecordingLaterInput() {
        var trace = BrowserPassiveTrace()
        trace.start(now: 0, active: true)
        XCTAssertTrue(trace.lines[1].contains("active=true"))
        trace.record(.typingOccurred, now: 30)
        XCTAssertFalse(trace.typingRecorded)
        XCTAssertEqual(trace.lines.count, 2)
        let lines = trace.finish(now: 30)
        XCTAssertTrue(lines.last!.contains("typingOccurred=false"))
    }

}

final class BrowserRecoveryIMERegressionTests: XCTestCase {
    func testRevalidationPreservesComposition() {
        let e = RemapEngine()
        e.isJapaneseMode = true
        e.targetAvailabilityChanged(isTarget: true)
        _ = e.keyDown(keycode: 0, mods: [], isPhysical: true)
        e.targetAvailabilityChanged(isTarget: false)
        e.targetAvailabilityChanged(isTarget: true)
        XCTAssertTrue(e.isComposing)
        XCTAssertEqual(e.keyDown(keycode: 36, mods: [], isPhysical: true), .passThrough)
    }
    func testCompositionStartedWhileWaitingForAXIsPreserved() {
        let e = RemapEngine()
        e.isJapaneseMode = true
        XCTAssertEqual(e.keyDown(keycode: 0, mods: [], isPhysical: true), .passThrough)
        e.targetAvailabilityChanged(isTarget: true)
        XCTAssertTrue(e.isComposing)
        XCTAssertEqual(e.keyDown(keycode: 36, mods: [], isPhysical: true), .passThrough)
        XCTAssertEqual(e.keyDown(keycode: 36, mods: [], isPhysical: true), .addShift)
    }
    func testKeyUpPairSurvivesCacheInvalidation() {
        let e = RemapEngine()
        e.targetAvailabilityChanged(isTarget: true)
        XCTAssertEqual(e.keyDown(keycode: 36, mods: [], isPhysical: true), .addShift)
        e.targetAvailabilityChanged(isTarget: false)
        XCTAssertEqual(e.keyUp(keycode: 36, mods: []), .addShift)
    }
    func testRealAppSwitchStillClearsCompositionAndPairs() {
        let e = RemapEngine()
        e.isJapaneseMode = true
        e.targetAvailabilityChanged(isTarget: true)
        _ = e.keyDown(keycode: 0, mods: [], isPhysical: true)
        e.frontmostChanged(isTarget: false)
        XCTAssertFalse(e.isComposing)
        XCTAssertEqual(e.keyUp(keycode: 36, mods: []), .passThrough)
    }
    func testActivityExcludesEnterSyntheticSourceHandledByCallerAndShortcuts() {
        XCTAssertFalse(RemapEngine.isTextInputActivity(keycode: 36, mods: []))
        XCTAssertFalse(RemapEngine.isTextInputActivity(keycode: 76, mods: []))
        XCTAssertFalse(RemapEngine.isTextInputActivity(keycode: 0, mods: [.command]))
        XCTAssertFalse(RemapEngine.isTextInputActivity(keycode: 0, mods: [.control]))
        XCTAssertTrue(RemapEngine.isTextInputActivity(keycode: 0, mods: []))
    }
}


final class BrowserNotificationGapRegressionTests: XCTestCase {
    private let measuredNotifications = [5875, 6201, 7622, 8910, 9141, 9351]

    /// Replay the recorded activation/notification/typing times, including ordinary
    /// 100ms housekeeping ticks. Fake AX takes a fixed latency and never calls Chrome.
    private func replay(workerMS: Int) -> [Int: Int] {
        var policy = BrowserRefreshPolicy()
        var work: (ticket: BrowserRefreshPolicy.Ticket, end: Int)?
        var cacheActive = false
        var gapStart: Int?
        var gaps: [Int: Int] = [:]
        let notifications = [4744, 4744, 4744, 4744, 4762, 4789] + measuredNotifications
        for ms in 4728...11000 {
            let now = Double(ms) / 1000
            var pump = (ms - 4728) % 100 == 0
            if ms == 4728 { policy.setActive(true, now: now); pump = true }
            for _ in notifications.filter({ $0 == ms }) {
                policy.invalidate(now: now)
                if cacheActive { gapStart = ms }
                cacheActive = false
                pump = true // next main-loop turn, not a 100ms timer wait
            }
            if ms == 5628 { policy.activity(now: now) }
            if let done = work, done.end == ms {
                if policy.complete(done.ticket, now: now) {
                    cacheActive = true
                    if let start = gapStart { gaps[start] = ms - start; gapStart = nil }
                }
                work = nil
                pump = true
            }
            if pump, let ticket = policy.begin(now: now) {
                XCTAssertNil(work)
                work = (ticket, ms + workerMS)
            }
        }
        return gaps
    }

    func testSixMeasuredGapsHaveNoPolicyWaitWithTwoMillisecondAX() {
        let gaps = replay(workerMS: 2)
        for ms in measuredNotifications { XCTAssertEqual(gaps[ms], 2, "notification at \(ms)") }
    }
    func testSixMeasuredGapsHaveNoPolicyWaitWithObservedWorstCaseAX() {
        let gaps = replay(workerMS: 12)
        for ms in measuredNotifications { XCTAssertEqual(gaps[ms], 12, "notification at \(ms)") }
    }
    func testNotificationCanStartWhilePreviousFixedCooldownWouldBlock() {
        var p = BrowserRefreshPolicy()
        p.setActive(true, now: 0)
        let first = p.begin(now: 0.1)!
        XCTAssertTrue(p.complete(first, now: 0.102))
        p.invalidate(now: 0.2)
        XCTAssertNotNil(p.begin(now: 0.2)) // old policy waited until>=0.35, then timer
    }
    func testInvalidationDuringAXRejectsOldResultAndAllowsImmediateNewGeneration() {
        var p = BrowserRefreshPolicy()
        p.setActive(true, now: 0)
        let first = p.begin(now: 0.1)!
        p.invalidate(now: 0.101)
        XCTAssertNil(p.begin(now: 0.101))
        XCTAssertFalse(p.complete(first, now: 0.102))
        let next = p.begin(now: 0.102)!
        XCTAssertNotEqual(first.generation, next.generation)
        XCTAssertTrue(p.complete(next, now: 0.104))
    }
    func testStormHasOnlyTwoImmediateCreditsThenRecoversWithoutNewNotification() {
        var p = BrowserRefreshPolicy()
        p.setActive(true, now: 0)
        for t in [0.1, 0.102] {
            p.invalidate(now: t)
            let ticket = p.begin(now: t)!
            XCTAssertTrue(p.complete(ticket, now: t))
        }
        p.invalidate(now: 0.104)
        XCTAssertNil(p.begin(now: 0.104))
        XCTAssertNil(p.begin(now: 0.34))
        XCTAssertNotNil(p.begin(now: 0.351))
    }
    func testAppSwitchCannotRefillBudgetOrAcceptOldBrowserResult() {
        var p = BrowserRefreshPolicy()
        p.setActive(true, now: 0)
        let first = p.begin(now: 0.1)!
        XCTAssertTrue(p.complete(first, now: 0.102))
        p.invalidate(now: 0.11)
        let second = p.begin(now: 0.11)!
        p.setActive(false, now: 0.111)
        p.setActive(true, now: 0.112)
        XCTAssertFalse(p.complete(second, now: 0.113))
        XCTAssertNil(p.begin(now: 0.2)) // enough settle time, but no budget
        XCTAssertNotNil(p.begin(now: 0.351))
    }
    func testRawClickKeepsSettleDelayDespiteFollowupNotification() {
        var p = BrowserRefreshPolicy()
        p.setActive(true, now: 0)
        let first = p.begin(now: 0.1)!
        XCTAssertTrue(p.complete(first, now: 0.102))
        p.invalidate(now: 0.2, settleDelay: 0.08)
        p.invalidate(now: 0.21)
        XCTAssertNil(p.begin(now: 0.279))
        XCTAssertNotNil(p.begin(now: 0.281))
    }
    func testOtherInputAndAddressBarStayInactiveDuringAndAfterReevaluation() {
        for result in [BrowserEvaluation(service: nil, reason: .browserTextInput),
                       BrowserEvaluation(service: nil, reason: .otherFocusedWeb),
                       BrowserEvaluation(service: nil, reason: .rejectedGeminiInput),
                       BrowserEvaluation(service: nil, reason: .secureInput),
                       BrowserEvaluation(service: nil, reason: .timedOut)] {
            var policy = BrowserRefreshPolicy()
            let engine = RemapEngine()
            policy.setActive(true, now: 0)
            let first = policy.begin(now: 0.1)!
            _ = policy.complete(first, now: 0.102)
            engine.targetAvailabilityChanged(isTarget: true)
            policy.invalidate(now: 0.2)
            engine.targetAvailabilityChanged(isTarget: false) // publish(nil) is retained
            XCTAssertEqual(engine.keyDown(keycode: 36, mods: [], isPhysical: true), .passThrough)
            let next = policy.begin(now: 0.2)!
            if policy.complete(next, now: 0.202) {
                engine.targetAvailabilityChanged(isTarget: result.service != nil)
            }
            XCTAssertFalse(engine.isTargetAppActive)
            XCTAssertEqual(engine.keyDown(keycode: 36, mods: [], isPhysical: true), .passThrough)
        }
    }
    func testNonBrowserSwitchDuringFastReevaluationDoesNotRestoreGemini() {
        var policy = BrowserRefreshPolicy()
        let engine = RemapEngine()
        policy.setActive(true, now: 0)
        let pending = policy.begin(now: 0.1)!
        policy.setActive(false, now: 0.101)
        engine.frontmostChanged(isTarget: false)
        if policy.complete(pending, now: 0.102) { engine.targetAvailabilityChanged(isTarget: true) }
        XCTAssertFalse(engine.isTargetAppActive)
        XCTAssertEqual(engine.keyDown(keycode: 36, mods: [], isPhysical: true), .passThrough)
    }
    func testFastRefreshKeepsCompositionAndKeyUpPairing() {
        let engine = RemapEngine()
        engine.targetAvailabilityChanged(isTarget: true)
        XCTAssertEqual(engine.keyDown(keycode: 36, mods: [], isPhysical: true), .addShift)
        engine.targetAvailabilityChanged(isTarget: false)
        engine.targetAvailabilityChanged(isTarget: true)
        XCTAssertEqual(engine.keyUp(keycode: 36, mods: []), .addShift)
        engine.isJapaneseMode = true
        _ = engine.keyDown(keycode: 0, mods: [], isPhysical: true)
        engine.targetAvailabilityChanged(isTarget: false)
        engine.targetAvailabilityChanged(isTarget: true)
        XCTAssertTrue(engine.isComposing)
        XCTAssertEqual(engine.keyDown(keycode: 36, mods: [], isPhysical: true), .passThrough)
    }
}
