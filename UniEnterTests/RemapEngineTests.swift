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
