import AppKit
import CoreGraphics
import os

/// CGEventTapの生成・破棄・自動再有効化を担当する。
/// イベントの解釈と書き換え判断は `handler` に委ねる。
final class EventTapManager {
    private let log = Logger(subsystem: "dev.iwai.UniEnter", category: "eventtap")

    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    /// タップしたイベントごとに呼ばれる。返したイベントが配送される(in-place改変可)。
    /// nilを返すとイベントは破棄される。
    var handler: (CGEventType, CGEvent) -> CGEvent? = { _, event in event }

    var isRunning: Bool {
        guard let tap else { return false }
        return CGEvent.tapIsEnabled(tap: tap)
    }

    /// タップを生成して開始する。アクセシビリティ未許可だと生成に失敗しfalseを返す。
    @discardableResult
    func start() -> Bool {
        guard tap == nil else { return true }

        let mask: CGEventMask =
            (CGEventMask(1) << CGEventType.keyDown.rawValue) |
            (CGEventMask(1) << CGEventType.keyUp.rawValue) |
            (CGEventMask(1) << CGEventType.leftMouseDown.rawValue)

        let refcon = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, type, event, refcon in
                guard let refcon else { return Unmanaged.passUnretained(event) }
                let manager = Unmanaged<EventTapManager>.fromOpaque(refcon).takeUnretainedValue()
                return manager.handle(type: type, event: event)
            },
            userInfo: refcon
        ) else {
            log.error("CGEvent.tapCreate failed (accessibility permission missing?)")
            return false
        }

        self.tap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        log.info("event tap started")
        return true
    }

    func stop() {
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
            runLoopSource = nil
        }
        if let tap {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFMachPortInvalidate(tap)
            self.tap = nil
        }
        log.info("event tap stopped")
    }

    /// スリープ復帰・セッション切替後に呼ぶ。無効化されていたら再有効化し、
    /// それでも復帰しない場合はタップを作り直す。
    func ensureEnabled() {
        guard let tap else { return }
        guard !CGEvent.tapIsEnabled(tap: tap) else { return }
        CGEvent.tapEnable(tap: tap, enable: true)
        if !CGEvent.tapIsEnabled(tap: tap) {
            log.warning("tap could not be re-enabled; recreating")
            stop()
            start()
        }
    }

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // タイムアウト等での無効化は即座に再有効化する(この間のイベントは素通り)
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            log.warning("tap disabled (type=\(type.rawValue)); re-enabling")
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        }
        return handler(type, event).map(Unmanaged.passUnretained)
    }
}
