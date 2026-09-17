import XCTest
@testable import UniEnter

final class RemapEngineTests: XCTestCase {

    private var engine: RemapEngine!

    private let returnKey: Int64 = 36
    private let keypadEnter: Int64 = 76
    private let keyA: Int64 = 0
    private let escape: Int64 = 53
    private let backspace: Int64 = 51
    private let space: Int64 = 49

    override func setUp() {
        super.setUp()
        engine = RemapEngine()
        engine.isEnabled = true
        engine.isTargetAppActive = true
        engine.isJapaneseMode = false
    }

    private func down(_ keycode: Int64, _ mods: RemapEngine.Modifiers = [], physical: Bool = true) -> RemapAction {
        engine.keyDown(keycode: keycode, mods: mods, isPhysical: physical)
    }

    // MARK: - 基本の書き換え(英語モード)

    func testPlainEnterBecomesShiftEnter() {
        XCTAssertEqual(down(returnKey), .addShift)
    }

    func testKeypadEnterBecomesShiftEnter() {
        XCTAssertEqual(down(keypadEnter), .addShift)
    }

    func testCmdEnterBecomesPlainEnter() {
        XCTAssertEqual(down(returnKey, [.command]), .stripCommand)
    }

    func testShiftEnterPassesThrough() {
        XCTAssertEqual(down(returnKey, [.shift]), .passThrough)
    }

    func testOtherModifierCombosPassThrough() {
        XCTAssertEqual(down(returnKey, [.command, .shift]), .passThrough)
        XCTAssertEqual(down(returnKey, [.option]), .passThrough)
        XCTAssertEqual(down(returnKey, [.control]), .passThrough)
    }

    // MARK: - ガード条件

    func testNonTargetAppPassesThrough() {
        engine.isTargetAppActive = false
        XCTAssertEqual(down(returnKey), .passThrough)
    }

    func testDisabledPassesThrough() {
        engine.isEnabled = false
        XCTAssertEqual(down(returnKey), .passThrough)
    }

    func testSyntheticEventPassesThrough() {
        // IME等が合成したイベント(sourceStateID != 1)は書き換えない
        XCTAssertEqual(down(returnKey, physical: false), .passThrough)
    }

    // MARK: - keyUp整合

    func testKeyUpMirrorsKeyDownRemap() {
        XCTAssertEqual(down(returnKey), .addShift)
        XCTAssertEqual(engine.keyUp(keycode: returnKey, mods: []), .addShift)
        // 2度目のkeyUpには適用されない
        XCTAssertEqual(engine.keyUp(keycode: returnKey, mods: []), .passThrough)
    }

    func testKeyUpForPassThroughIsUntouched() {
        XCTAssertEqual(down(returnKey, [.shift]), .passThrough)
        XCTAssertEqual(engine.keyUp(keycode: returnKey, mods: [.shift]), .passThrough)
    }

    func testAppSwitchClearsActiveRemaps() {
        XCTAssertEqual(down(returnKey), .addShift)
        engine.frontmostChanged(isTarget: true)
        XCTAssertEqual(engine.keyUp(keycode: returnKey, mods: []), .passThrough)
    }

    // MARK: - IME変換中スルー(日本語モード)

    func testComposingEnterPassesThroughAndEndsComposition() {
        engine.isJapaneseMode = true
        XCTAssertEqual(down(keyA), .passThrough)          // 「あ」入力 → 変換中
        XCTAssertTrue(engine.isComposing)
        XCTAssertEqual(down(returnKey), .passThrough)     // 確定Enterは無加工
        XCTAssertFalse(engine.isComposing)
        XCTAssertEqual(down(returnKey), .addShift)        // 確定後のEnterは改行化
    }

    func testComposingCmdEnterPassesThrough() {
        engine.isJapaneseMode = true
        _ = down(keyA)
        XCTAssertEqual(down(returnKey, [.command]), .passThrough)
    }

    func testJapaneseModeWithoutCompositionRewrites() {
        engine.isJapaneseMode = true
        XCTAssertEqual(down(returnKey), .addShift)
        XCTAssertEqual(down(returnKey, [.command]), .stripCommand)
    }

    func testEnglishModeNeverComposes() {
        _ = down(keyA)
        XCTAssertFalse(engine.isComposing)
        XCTAssertEqual(down(returnKey), .addShift)
    }

    func testMouseClickEndsComposition() {
        engine.isJapaneseMode = true
        _ = down(keyA)
        engine.mouseDown()
        XCTAssertFalse(engine.isComposing)
        XCTAssertEqual(down(returnKey), .addShift)
    }

    func testInputSourceChangeEndsComposition() {
        engine.isJapaneseMode = true
        _ = down(keyA)
        engine.inputSourceChanged(isJapanese: false)
        XCTAssertFalse(engine.isComposing)
    }

    func testAppSwitchEndsComposition() {
        engine.isJapaneseMode = true
        _ = down(keyA)
        engine.frontmostChanged(isTarget: true)
        XCTAssertFalse(engine.isComposing)
    }

    func testCmdShortcutEndsComposition() {
        engine.isJapaneseMode = true
        _ = down(keyA)
        _ = down(keyA, [.command]) // Cmd+A等
        XCTAssertFalse(engine.isComposing)
    }

    // MARK: - 安全側に倒す(状態維持)ケース

    func testCtrlKeyKeepsComposition() {
        // Ctrl+K(カタカナ変換)等は変換中の操作 → フラグ維持
        engine.isJapaneseMode = true
        _ = down(keyA)
        _ = down(40, [.control]) // keycode 40 = K
        XCTAssertTrue(engine.isComposing)
        XCTAssertEqual(down(returnKey), .passThrough)
    }

    func testEscapeKeepsComposition() {
        // Escは変換を終えるとは限らない(ことえり: 候補選択からひらがなに戻るだけ)
        engine.isJapaneseMode = true
        _ = down(keyA)
        _ = down(escape)
        XCTAssertTrue(engine.isComposing)
    }

    func testBackspaceKeepsComposition() {
        engine.isJapaneseMode = true
        _ = down(keyA)
        _ = down(backspace)
        XCTAssertTrue(engine.isComposing)
    }

    func testSpaceDoesNotStartComposition() {
        // 非変換中のSpace(全角スペース入力)で変換中扱いにしない
        engine.isJapaneseMode = true
        _ = down(space)
        XCTAssertFalse(engine.isComposing)
    }

    func testSpaceDuringCompositionKeepsIt() {
        // 変換中のSpace = 変換操作。フラグは維持される
        engine.isJapaneseMode = true
        _ = down(keyA)
        _ = down(space)
        XCTAssertTrue(engine.isComposing)
        XCTAssertEqual(down(returnKey), .passThrough)
    }

    func testJISKanaKeysStartComposition() {
        engine.isJapaneseMode = true
        _ = down(93) // JIS ¥
        XCTAssertTrue(engine.isComposing)
    }
}

// MARK: - 候補ポップアップ(@メンション等)のEnter素通し

final class RemapEngineSuggestionTests: XCTestCase {

    private var engine: RemapEngine!

    private let returnKey: Int64 = 36
    private let keypadEnter: Int64 = 76
    private let space: Int64 = 49
    private let tab: Int64 = 48
    private let escape: Int64 = 53
    private let backspace: Int64 = 51
    private let leftArrow: Int64 = 123
    private let downArrow: Int64 = 125
    private let upArrow: Int64 = 126

    override func setUp() {
        super.setUp()
        engine = RemapEngine()
        engine.isEnabled = true
        engine.isTargetAppActive = true
        engine.isJapaneseMode = false
    }

    /// 文字キー。keycodeは判定に影響しない(0...50の範囲なら変換開始扱いになる)
    @discardableResult
    private func type(_ text: String, mods: RemapEngine.Modifiers = []) -> RemapAction {
        var last: RemapAction = .passThrough
        for ch in text {
            let keycode: Int64 = ch == " " ? space : 0
            last = engine.keyDown(keycode: keycode, mods: mods, isPhysical: true, characters: ch == " " ? " " : String(ch))
        }
        return last
    }

    private func press(_ keycode: Int64, _ mods: RemapEngine.Modifiers = []) -> RemapAction {
        engine.keyDown(keycode: keycode, mods: mods, isPhysical: true, characters: "")
    }

    // MARK: 基本

    func testMentionEnterPassesThrough() {
        type("hello @tan")
        XCTAssertTrue(engine.isSuggesting)
        XCTAssertEqual(press(returnKey), .passThrough)
        // 確定後は通常どおり改行化に戻る
        XCTAssertFalse(engine.isSuggesting)
        XCTAssertEqual(press(returnKey), .addShift)
    }

    func testMentionAtMessageStart() {
        type("@tan")
        XCTAssertEqual(press(returnKey), .passThrough)
    }

    func testKeypadEnterAlsoPassesThrough() {
        type("@tan")
        XCTAssertEqual(press(keypadEnter), .passThrough)
    }

    func testMentionEnterDoesNotRegisterKeyUpRemap() {
        type("@tan")
        XCTAssertEqual(press(returnKey), .passThrough)
        XCTAssertEqual(engine.keyUp(keycode: returnKey, mods: []), .passThrough)
    }

    func testChannelTriggerPassesThrough() {
        type("see #gen")
        XCTAssertEqual(press(returnKey), .passThrough)
    }

    func testEmojiTriggerNeedsTwoCharacters() {
        type(":s")
        XCTAssertFalse(engine.isSuggesting)
        XCTAssertEqual(press(returnKey), .addShift)

        type(":sm")
        XCTAssertTrue(engine.isSuggesting)
        XCTAssertEqual(press(returnKey), .passThrough)
    }

    func testSlashCommandOnlyAtLineStart() {
        type("/rem")
        XCTAssertEqual(press(returnKey), .passThrough)

        type("foo /rem")
        XCTAssertFalse(engine.isSuggesting)
        XCTAssertEqual(press(returnKey), .addShift)
    }

    func testSlashAfterNewlineCountsAsLineStart() {
        type("foo")
        XCTAssertEqual(press(returnKey), .addShift)
        type("/rem")
        XCTAssertEqual(press(returnKey), .passThrough)
    }

    // MARK: 誤送信を防ぐ(候補が開かない場面では改行のまま)

    func testAtInsideWordIsNotATrigger() {
        // メールアドレス等の語中 @ では候補は開かない
        type("mail foo@bar")
        XCTAssertFalse(engine.isSuggesting)
        XCTAssertEqual(press(returnKey), .addShift)
    }

    func testColonInsideWordIsNotATrigger() {
        type("at 10:30")
        XCTAssertEqual(press(returnKey), .addShift)
    }

    func testBareColonThenEnterIsNewline() {
        type("note:")
        XCTAssertEqual(press(returnKey), .addShift)
    }

    func testModifiedEnterIsUnaffected() {
        type("@tan")
        XCTAssertEqual(press(returnKey, [.command]), .stripCommand)
        XCTAssertFalse(engine.isSuggesting)

        type("@tan")
        XCTAssertEqual(press(returnKey, [.shift]), .passThrough)
        XCTAssertFalse(engine.isSuggesting)
    }

    // MARK: 候補が閉じる操作

    func testSpaceEndsSuggestion() {
        type("@tan ")
        XCTAssertFalse(engine.isSuggesting)
        XCTAssertEqual(press(returnKey), .addShift)
    }

    func testEscapeEndsSuggestion() {
        type("@tan")
        _ = press(escape)
        XCTAssertEqual(press(returnKey), .addShift)
    }

    func testTabEndsSuggestion() {
        type("@tan")
        _ = press(tab)
        XCTAssertEqual(press(returnKey), .addShift)
    }

    func testMouseClickEndsSuggestion() {
        type("@tan")
        engine.mouseDown()
        XCTAssertEqual(press(returnKey), .addShift)
    }

    func testAppSwitchEndsSuggestion() {
        type("@tan")
        engine.frontmostChanged(isTarget: true)
        XCTAssertEqual(press(returnKey), .addShift)
    }

    func testCursorMoveEndsSuggestion() {
        type("@tan")
        _ = press(leftArrow)
        XCTAssertEqual(press(returnKey), .addShift)
    }

    func testCmdShortcutEndsSuggestion() {
        type("@tan")
        type("v", mods: [.command])
        XCTAssertEqual(press(returnKey), .addShift)
    }

    func testUpDownKeepsSuggestion() {
        // 候補リスト内の移動
        type("@tan")
        _ = press(downArrow)
        _ = press(upArrow)
        XCTAssertEqual(press(returnKey), .passThrough)
    }

    func testBackspaceWithinNameKeepsSuggestion() {
        type("@tan")
        _ = press(backspace)
        XCTAssertTrue(engine.isSuggesting)
        XCTAssertEqual(press(returnKey), .passThrough)
    }

    func testBackspaceDeletingTriggerEndsSuggestion() {
        type("@t")
        _ = press(backspace)
        _ = press(backspace) // @ 自体を消した
        XCTAssertFalse(engine.isSuggesting)
        XCTAssertEqual(press(returnKey), .addShift)
    }

    func testBackspaceBreaksWordBoundary() {
        // 削除後は直前の文字が分からないので、単語頭扱いしない(安全側)
        type("foo ")
        _ = press(backspace)
        type("@tan")
        XCTAssertEqual(press(returnKey), .addShift)
    }

    // MARK: 日本語IMEとの組み合わせ

    func testMentionSurvivesSwitchToJapaneseAndComposition() {
        // 英数で @ → かなキー → 名前を変換 → 確定Enter → 候補確定Enter
        type("@")
        engine.inputSourceChanged(isJapanese: true)
        _ = press(0)                        // 「た」入力 → 変換中
        _ = press(space)                    // 変換
        XCTAssertTrue(engine.isComposing)
        XCTAssertEqual(press(returnKey), .passThrough) // 確定
        XCTAssertFalse(engine.isComposing)
        XCTAssertTrue(engine.isSuggesting)
        XCTAssertEqual(press(returnKey), .passThrough) // 候補確定
        XCTAssertFalse(engine.isSuggesting)
        XCTAssertEqual(press(returnKey), .addShift)
    }

    func testAtTypedInJapaneseModeIsNotATrigger() {
        // 日本語モードの @ はIMEが全角にすることがあり候補が開くか不明 → 対象外
        engine.isJapaneseMode = true
        _ = engine.keyDown(keycode: 19, mods: [.shift], isPhysical: true, characters: "@")
        XCTAssertEqual(press(returnKey), .passThrough) // 変換確定
        XCTAssertFalse(engine.isSuggesting)
        XCTAssertEqual(press(returnKey), .addShift)
    }

    func testSuggestionIgnoredWhenNotTargetApp() {
        engine.isTargetAppActive = false
        type("@tan")
        XCTAssertFalse(engine.isSuggesting)
    }
}
