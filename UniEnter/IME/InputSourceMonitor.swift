import Carbon
import Foundation

/// 現在の入力ソースが日本語IMEかどうかをキャッシュする。
/// CGEventTapコールバック内からTIS APIを呼ばないための前段キャッシュ。
final class InputSourceMonitor {
    private(set) var isJapaneseMode = false
    var onChange: ((Bool) -> Void)?

    init() {
        refresh()
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(inputSourceDidChange),
            name: NSNotification.Name(kTISNotifySelectedKeyboardInputSourceChanged as String),
            object: nil
        )
    }

    deinit {
        DistributedNotificationCenter.default().removeObserver(self)
    }

    @objc private func inputSourceDidChange() {
        refresh()
        // モードが同じでも通知する: 英数/かなキーによる切替は未確定文字列を確定させるため、
        // 受け側で変換中フラグをクリアする必要がある。
        onChange?(isJapaneseMode)
    }

    /// 通知取りこぼしに備え、アプリ切替時などにも呼んでよい(軽量)。
    func refresh() {
        guard let source = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue() else {
            isJapaneseMode = false
            return
        }
        // IMEでない入力ソース(ABC等)はInputModeIDを持たない。
        // ことえり: com.apple.inputmethod.Kotoeri.RomajiTyping.Japanese
        // Google日本語入力: com.google.inputmethod.Japanese.base
        if let pointer = TISGetInputSourceProperty(source, kTISPropertyInputModeID) {
            let modeID = Unmanaged<CFString>.fromOpaque(pointer).takeUnretainedValue() as String
            isJapaneseMode = modeID.range(of: "japanese", options: .caseInsensitive) != nil
        } else {
            isJapaneseMode = false
        }
    }
}
