import Foundation

/// Main-thread scheduler only. AX stays on one worker; no trailing-edge starvation.
/// Recovery is activity-bounded, not a permanent background AX poll.
struct BrowserRefreshPolicy {
    struct Ticket: Equatable { let serial: Int; let generation: Int }
    private(set) var generation = 0
    private(set) var active = false
    private(set) var inFlight: Ticket?
    private var serial = 0
    private var due: TimeInterval?
    private var recoveryUntil: TimeInterval = 0
    private var lastStart: TimeInterval = -.infinity
    private var settledAfter: TimeInterval = 0
    // Permit a short burst without a 250ms blind interval after every notification.
    // Credit survives app switches; toggling contexts cannot reset the rate limit.
    private var credits: Double = 2
    private var budgetUpdatedAt: TimeInterval?
    static let burstCapacity: Double = 2
    static let evaluationsPerSecond: Double = 4
    static let retryInterval: TimeInterval = 0.5
    static let recoveryDuration: TimeInterval = 1.5

    mutating func setActive(_ value: Bool, now: TimeInterval) {
        active = value
        generation += 1
        due = nil
        recoveryUntil = 0
        settledAfter = 0
        // An old worker must finish before another starts, even across app switches.
        if value { invalidate(now: now, settleDelay: 0.08) }
    }
    mutating func invalidate(now: TimeInterval, settleDelay: TimeInterval = 0) {
        guard active else { return }
        generation += 1
        recoveryUntil = now + Self.recoveryDuration
        // Notifications describe a change that already occurred. Do not debounce them.
        // A raw mouseDown precedes delivery to Chrome, so its existing settle delay stays.
        settledAfter = max(settledAfter, now + settleDelay)
        request(at: now)
    }
    mutating func activity(now: TimeInterval) {
        guard active else { return }
        recoveryUntil = now + Self.recoveryDuration
        request(at: max(now, lastStart + Self.retryInterval))
    }
    private mutating func request(at time: TimeInterval) {
        due = min(due ?? time, time)
    }
    mutating func begin(now: TimeInterval) -> Ticket? {
        guard active, inFlight == nil, let due, now >= due, now >= settledAfter else { return nil }
        if let previous = budgetUpdatedAt {
            credits = min(Self.burstCapacity, credits + max(0, now - previous) * Self.evaluationsPerSecond)
        }
        budgetUpdatedAt = now
        guard credits >= 1 else { return nil }
        credits -= 1
        self.due = nil
        lastStart = now
        serial += 1
        let ticket = Ticket(serial: serial, generation: generation)
        inFlight = ticket
        return ticket
    }
    /// False means a newer focus/app/setting invalidated this result.
    mutating func complete(_ ticket: Ticket, now: TimeInterval) -> Bool {
        guard inFlight == ticket else { return false }
        inFlight = nil
        guard active else { return false }
        if now + Self.retryInterval <= recoveryUntil { request(at: now + Self.retryInterval) }
        return ticket.generation == generation
    }
}

/// Typed, bounded, local-only passive telemetry; no arbitrary text or key data API.
struct BrowserPassiveTrace {
    enum Event: String { case started, activated, deactivated, focusNotification, otherNotification,
        titleNotification, focusedWindowNotification, mainWindowNotification, invalidated, evaluationStarted, evaluationFinished, cacheChanged, typingOccurred, finished }
    static let duration: TimeInterval = 30
    static let maximumLines = 256
    private var entries: [String] = []
    private var nextOverwrite = 0
    private var wrapped = false
    private var footer: String?
    var lines: [String] {
        let ordered = wrapped ? Array(entries[nextOverwrite...] + entries[..<nextOverwrite]) : entries
        return ["UniEnter passive trace; no additional AX queries; no text/keycodes/titles/URLs"]
            + ordered + (footer.map { [$0] } ?? [])
    }
    private(set) var startedAt: TimeInterval?
    private(set) var typingRecorded = false
    mutating func start(now: TimeInterval, active: Bool = false) {
        startedAt = now
        typingRecorded = false
        entries = []
        entries.reserveCapacity(Self.maximumLines - 2)
        nextOverwrite = 0
        wrapped = false
        footer = nil
        record(.started, now: now, active: active)
    }
    func expired(now: TimeInterval) -> Bool {
        startedAt.map { now - $0 >= Self.duration } ?? false
    }
    mutating func record(_ event: Event, now: TimeInterval, generation: Int = 0,
                         active: Bool = false, reason: BrowserEvaluationReason? = nil,
                         accepted: Bool? = nil) {
        guard let start = startedAt, now - start < Self.duration else { return }
        if event == .typingOccurred {
            guard !typingRecorded else { return }
            typingRecorded = true
        }
        var line = "ms=\(Int(max(0, now - start) * 1000)) event=\(event.rawValue) generation=\(generation) active=\(active)"
        if let reason { line += " reason=\(reason.rawValue)" }
        if let accepted { line += " accepted=\(accepted)" }
        if entries.count < Self.maximumLines - 2 { entries.append(line) }
        else {
            entries[nextOverwrite] = line
            nextOverwrite = (nextOverwrite + 1) % entries.count
            wrapped = true
        }
    }
    mutating func finish(now: TimeInterval) -> [String] {
        guard let start = startedAt else { return [] }
        footer = "ms=\(Int(max(0, now - start) * 1000)) event=finished typingOccurred=\(typingRecorded) capped=\(wrapped)"
        startedAt = nil
        return lines
    }
}
