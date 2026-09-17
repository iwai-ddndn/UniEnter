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
/// ただし候補ポップアップ(下記)だけは例外で、素通しがそのまま「送信」になりうるため、
/// こちらは「迷ったら改行(addShift)に倒す」。
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

    // MARK: - 候補ポップアップ(@メンション等)の推定

    /// チャットアプリの入力欄で `@` `#` `:` `/` を打つと候補リストが開き、Enterで確定(フィルイン)
    /// する。このEnterをShift+Enterに書き換えると候補が選ばれず改行が入ってしまうため、
    /// 「候補が開いていそう」な間の素のEnterだけは無加工で通す。
    ///
    /// ポップアップの有無はAXでは取れない(Electronの動的DOM)ので、IME変換中と同じく
    /// キーシーケンスから推定する。誤って「開いている」と判定すると素通しEnterが送信に
    /// なりうるため、こちらの推定は変換中推定とは逆に、迷ったら「閉じている」側へ倒す。
    private struct SuggestionTrigger {
        /// 行頭でのみ開く(スラッシュコマンド)。falseなら単語頭(空白・行頭の直後)で開く
        var lineStartOnly = false
        /// トリガー後にこの文字数を打つまで候補が出ない(Slack/Discordの絵文字 `:` は2文字)
        var minKeystrokes = 0
    }

    private static let suggestionTriggers: [Character: SuggestionTrigger] = [
        "@": SuggestionTrigger(),                        // メンション(全対象アプリ共通)
        "#": SuggestionTrigger(),                        // チャンネル(Slack/Discord)
        ":": SuggestionTrigger(minKeystrokes: 2),        // 絵文字(Slack/Discord/Teams)
        "/": SuggestionTrigger(lineStartOnly: true),     // スラッシュコマンド(Slack/Discord)
    ]

    /// カーソル移動系: 候補は閉じ、直前の文字も分からなくなる
    private static let cursorKeycodes: Set<Int64> = [123, 124, 115, 119, 116, 121, 117] // ← → Home End PgUp PgDn 前方Delete
    private static let upDownKeycodes: Set<Int64> = [125, 126]
    private static let spaceKeycode: Int64 = 49
    private static let tabKeycode: Int64 = 48
    private static let escapeKeycode: Int64 = 53
    private static let backspaceKeycode: Int64 = 51

    /// トリガー文字が打たれて候補が開いた可能性がある(minKeystrokes未達も含む)
    private var activeTrigger: SuggestionTrigger?
    /// トリガー以降に打った文字数(Backspaceでトリガー自体を消したら候補終了)
    private var suggestionKeystrokes = 0
    /// 直前が空白・行頭など「単語の頭」か(メールアドレス等の語中 `@` を除外する)
    private var atWordBoundary = true
    /// 行頭か(スラッシュコマンド用)
    private var atLineStart = true

    /// 候補ポップアップが開いていそうか(この間の素のEnterは候補確定として素通し)
    var isSuggesting: Bool {
        guard let trigger = activeTrigger else { return false }
        return suggestionKeystrokes >= trigger.minKeystrokes
    }

    // MARK: - イベント入力

    /// - Parameter characters: そのキーがキーボード配列上で生成する文字列(CGEventのUnicode文字列)。
    ///   IMEを通す前の値でよい。トリガー文字(`@`等)の判定にのみ使い、不明なら空文字。
    func keyDown(keycode: Int64, mods: Modifiers, isPhysical: Bool, characters: String = "") -> RemapAction {
        guard isEnabled, isTargetAppActive else { return .passThrough }
        // IME等が合成(post)したイベントは無条件素通し(物理キーのみ書き換え対象)
        guard isPhysical else { return .passThrough }

        if Self.returnKeycodes.contains(keycode) {
            if isJapaneseMode && isComposing {
                // 変換確定のEnter。IMEに無加工で渡す(アプリ側もisComposingで送信しない)。
                // 候補ポップアップは確定後も開いたままなので推定状態は維持する
                isComposing = false
                return .passThrough
            }
            let relevant = mods.intersection([.shift, .command, .control, .option])
            if relevant.isEmpty && isSuggesting {
                // 候補の確定Enter。無加工で通す(Shift付きだと候補が選ばれず改行になる)。
                // 確定後は「@name 」のように空白付きでフィルインされるので単語頭扱い
                endSuggestion()
                atWordBoundary = true
                atLineStart = false
                return .passThrough
            }
            let action: RemapAction
            switch relevant {
            case []: action = .addShift
            case [.command]: action = .stripCommand
            default: action = .passThrough // Shift+Enter等は既に改行として機能する
            }
            if action != .passThrough {
                activeRemaps[keycode] = action
            }
            // 改行でも送信でも候補は閉じ、カーソルは行頭に来る
            endSuggestion()
            atWordBoundary = true
            atLineStart = true
            return action
        }

        updateComposition(keycode: keycode, mods: mods)
        updateSuggestion(keycode: keycode, mods: mods, characters: characters)
        return .passThrough
    }

    func keyUp(keycode: Int64, mods: Modifiers) -> RemapAction {
        guard let action = activeRemaps.removeValue(forKey: keycode) else { return .passThrough }
        return action
    }

    /// 左クリック: 未確定文字列はクリックで確定されるため変換中フラグを下ろす。
    /// 候補ポップアップもクリックで閉じる(候補をクリックで選んだ場合も含む)
    func mouseDown() {
        isComposing = false
        endSuggestion()
        // クリック先は分からないが、入力欄へのクリックは文末か空欄がほとんどなので
        // 直後の `@` `/` は候補トリガーとして扱う(ここを安全側に倒すと
        // 「入力欄をクリック → @name → Enter」という最も普通の流れが直らない)
        atWordBoundary = true
        atLineStart = true
    }

    /// 入力ソースが変わった(英数キー・かなキー含む)
    func inputSourceChanged(isJapanese: Bool) {
        isJapaneseMode = isJapanese
        isComposing = false
        // 「英数で @ → かなに切替 → 名前を入力」の流れがあるため候補推定は維持する
    }

    /// 前面アプリが切り替わった
    func frontmostChanged(isTarget: Bool) {
        isTargetAppActive = isTarget
        isComposing = false
        activeRemaps.removeAll()
        endSuggestion()
        atWordBoundary = true
        // 下書きが残っていて文中にカーソルがある可能性があるので、行頭限定の `/` は開かない
        atLineStart = false
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

    // MARK: - 候補ポップアップ推定

    private func endSuggestion() {
        activeTrigger = nil
        suggestionKeystrokes = 0
    }

    private func updateSuggestion(keycode: Int64, mods: Modifiers, characters: String) {
        // 日本語の変換中は、IMEの中で完結する操作(変換・Esc・Backspace等)なので
        // ポップアップの状態は変わらない。確定した文字列はまとめて候補の絞り込みに使われる
        if isJapaneseMode && isComposing { return }

        if mods.contains(.command) || mods.contains(.control) {
            // ショートカット。カーソル位置も内容も分からなくなるので閉じる側へ
            endSuggestion()
            atWordBoundary = false
            atLineStart = false
            return
        }

        switch keycode {
        case Self.spaceKeycode:
            // Slackは名前の途中の空白でも候補を維持するが、一致なしで閉じるケースと
            // 区別できないため閉じたとみなす(誤送信よりメンション不成立の方がまし)
            endSuggestion()
            atWordBoundary = true
            atLineStart = false
        case Self.tabKeycode:
            // Tabは候補確定(アプリによる)かフォーカス移動
            endSuggestion()
            atWordBoundary = true
            atLineStart = false
        case Self.escapeKeycode:
            endSuggestion()
        case Self.backspaceKeycode:
            if activeTrigger != nil {
                if suggestionKeystrokes == 0 {
                    endSuggestion() // トリガー文字自体を消した
                } else {
                    suggestionKeystrokes -= 1
                }
            }
            atWordBoundary = false
            atLineStart = false
        case _ where Self.upDownKeycodes.contains(keycode):
            // 候補が開いていれば候補の移動。開いていなければ行移動(位置不明)
            if activeTrigger == nil {
                atWordBoundary = false
                atLineStart = false
            }
        case _ where Self.cursorKeycodes.contains(keycode):
            endSuggestion()
            atWordBoundary = false
            atLineStart = false
        default:
            guard let ch = characters.first, characters.count == 1,
                  !ch.isWhitespace, !ch.isNewline,
                  ch.unicodeScalars.allSatisfy({ !$0.properties.generalCategory.isControlLike }) else {
                // ファンクションキー等、文字を生まないキー。何が起きたか分からないので閉じる側へ
                endSuggestion()
                atWordBoundary = false
                atLineStart = false
                return
            }
            if activeTrigger != nil {
                suggestionKeystrokes += 1
            } else if !isJapaneseMode, let trigger = Self.suggestionTriggers[ch],
                      trigger.lineStartOnly ? atLineStart : atWordBoundary {
                // 日本語モードで打った `@` はIMEが全角にする可能性があり、候補が開くか
                // 分からないので対象外(英数モードで打った `@` のみ)
                activeTrigger = trigger
                suggestionKeystrokes = 0
            }
            atWordBoundary = false
            atLineStart = false
        }
    }
}

private extension Unicode.GeneralCategory {
    var isControlLike: Bool {
        switch self {
        case .control, .format, .privateUse, .surrogate, .unassigned: return true
        default: return false
        }
    }
}
