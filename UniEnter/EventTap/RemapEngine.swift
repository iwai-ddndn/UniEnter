import Foundation

/// キー書き換えの判断結果。
enum RemapAction: Equatable {
    case passThrough
    /// Enter → Shift+Enter(改行)
    case addShift
    /// Cmd+Enter → Enter(送信)
    case stripCommand
}

/// キー書き換えの判定ロジック本体。CGEventに依存しない純粋な状態機械として保ち、
/// ユニットテスト可能にする。スレッドはメインランループ前提(排他制御なし)。
///
/// 方針: 判定不能・想定外の状態では常に「加工しない(passThrough)」側へ倒す。
final class RemapEngine {

    struct Modifiers: OptionSet, Equatable {
        let rawValue: Int
        static let shift = Modifiers(rawValue: 1 << 0)
        static let command = Modifiers(rawValue: 1 << 1)
        static let control = Modifiers(rawValue: 1 << 2)
        static let option = Modifiers(rawValue: 1 << 3)
    }

    // MARK: - 外部から更新される状態

    /// メニューからの一時停止用マスタースイッチ
    var isEnabled = true
    /// 前面アプリが対象チャットアプリか(NSWorkspace通知で更新)
    var isTargetAppActive = false
    /// 現在の入力ソースが日本語IMEか(TIS通知で更新)
    var isJapaneseMode = false

    // MARK: - 内部状態

    /// 日本語モードで「未確定文字列がありそうか」のキーシーケンス推定フラグ
    private(set) var isComposing = false
    /// keyDownで書き換えたキーは対応するkeyUpにも同じ変換を適用する(押下中の整合性)
    private var activeRemaps: [Int64: RemapAction] = [:]

    private static let returnKeycodes: Set<Int64> = [36, 76] // Return, テンキーEnter

    /// 文字を生成しうるキー(英数字・記号・かな刻印)。これらのkeyDownで変換開始とみなす。
    /// Return(36)/Tab(48)/Space(49)は除外 — 非変換中のSpaceは変換を開始しないため。
    private static let textKeycodes: Set<Int64> = {
        var set = Set<Int64>(0...50)
        set.subtract([36, 48, 49])
        set.formUnion([93, 94]) // JIS配列の ¥ と _(ろ)
        return set
    }()

    // MARK: - イベント入力

    func keyDown(keycode: Int64, mods: Modifiers, isPhysical: Bool) -> RemapAction {
        guard isEnabled, isTargetAppActive else { return .passThrough }
        // IME等が合成(post)したイベントは無条件素通し(物理キーのみ書き換え対象)
        guard isPhysical else { return .passThrough }

        if Self.returnKeycodes.contains(keycode) {
            if isJapaneseMode && isComposing {
                // 変換確定のEnter。IMEに無加工で渡す(アプリ側もisComposingで送信しない)
                isComposing = false
                return .passThrough
            }
            let action: RemapAction
            let relevant = mods.intersection([.shift, .command, .control, .option])
            switch relevant {
            case []: action = .addShift
            case [.command]: action = .stripCommand
            default: action = .passThrough // Shift+Enter等は既に改行として機能する
            }
            if action != .passThrough {
                activeRemaps[keycode] = action
            }
            return action
        }

        updateComposition(keycode: keycode, mods: mods)
        return .passThrough
    }

    func keyUp(keycode: Int64, mods: Modifiers) -> RemapAction {
        guard let action = activeRemaps.removeValue(forKey: keycode) else { return .passThrough }
        return action
    }

    /// 左クリック: 未確定文字列はクリックで確定されるため変換中フラグを下ろす
    func mouseDown() {
        isComposing = false
    }

    /// 入力ソースが変わった(英数キー・かなキー含む)
    func inputSourceChanged(isJapanese: Bool) {
        isJapaneseMode = isJapanese
        isComposing = false
    }

    /// 前面アプリが切り替わった
    func frontmostChanged(isTarget: Bool) {
        isTargetAppActive = isTarget
        isComposing = false
        activeRemaps.removeAll()
    }

    // MARK: - 変換中推定

    private func updateComposition(keycode: Int64, mods: Modifiers) {
        guard isJapaneseMode else {
            isComposing = false
            return
        }
        if mods.contains(.command) {
            // Cmdショートカットは変換状態では通常使わない(押せば確定される)
            isComposing = false
            return
        }
        if mods.contains(.control) {
            // Ctrl+K(カタカナ変換)等は変換中の操作なので状態を維持(安全側)
            return
        }
        if Self.textKeycodes.contains(keycode) {
            isComposing = true
        }
        // Escape/Backspace/矢印等は状態維持: 変換を終えるとは限らず、
        // 誤ってフラグを下ろすと確定Enterを書き換えてしまうため素通し側へ倒す。
    }
}
