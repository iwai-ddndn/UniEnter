import AppKit
import XCTest
import SwiftUI
@testable import UniEnter

final class ApplicationMenuTests: XCTestCase {
    func testEditingShortcutsUseResponderChain() throws {
        let menu = ApplicationMenu.makeMainMenu()
        let edit = try XCTUnwrap(menu.items.last?.submenu)
        for (key, action) in [("x", "cut:"), ("c", "copy:"), ("v", "paste:"), ("a", "selectAll:"), ("z", "undo:")] {
            let item = try XCTUnwrap(edit.items.first { $0.action == Selector(action) })
            XCTAssertEqual(item.keyEquivalent, key)
            XCTAssertEqual(item.keyEquivalentModifierMask, .command)
            XCTAssertNil(item.target, "Editing must follow the current first responder")
        }
        let redo = try XCTUnwrap(edit.items.first { $0.action == Selector(("redo:")) })
        XCTAssertEqual(redo.keyEquivalent, "z")
        XCTAssertEqual(redo.keyEquivalentModifierMask, [.command, .shift])
        XCTAssertNil(redo.target)
    }

    func testMainMenuInstalledAtLaunch() {
        let editItems = NSApp.mainMenu?.items.flatMap { $0.submenu?.items ?? [] } ?? []
        XCTAssertTrue(editItems.contains { $0.action == #selector(NSText.paste(_:)) && $0.keyEquivalent == "v" })
    }


    /// 実際の LicenseView を使う。認証は呼ばず、状態は専用の使い捨て領域に隔離する。
    @MainActor
    func testLicenseFieldPasteThroughResponderChain() throws {
        let suite = "LicensePasteTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(suite)
        defer {
            defaults.removePersistentDomain(forName: suite)
            try? FileManager.default.removeItem(at: directory)
        }
        let model = LicenseViewModel(manager: LicenseManager(defaults: defaults, markerURL: directory.appendingPathComponent(".trial")))
        let hosting = NSHostingController(rootView: LicenseView(model: model))
        hosting.sizingOptions = [.preferredContentSize]
        let window = NSWindow(contentViewController: hosting)
        window.styleMask = [.titled, .closable, .resizable]
        window.isReleasedWhenClosed = false
        let originalMenu = NSApp.mainMenu
        let originalNextResponder = NSApp.nextResponder
        defer {
            NSApp.mainMenu = originalMenu
            window.close()
            NSApp.nextResponder = originalNextResponder
        }
        hosting.view.layoutSubtreeIfNeeded()
        func textField(in view: NSView) -> NSTextField? {
            if let field = view as? NSTextField, field.isEditable { return field }
            return view.subviews.lazy.compactMap { textField(in: $0) }.first
        }
        let field = try XCTUnwrap(textField(in: hosting.view))
        XCTAssertTrue(window.makeFirstResponder(field))
        let editor = try XCTUnwrap(field.currentEditor() as? NSTextView)
        XCTAssertTrue(window.firstResponder === editor)
        // テストランナーのウィンドウフォーカスに依存せず、通常の nil-target 配送を検証。
        NSApp.nextResponder = editor
        XCTAssertTrue(NSApp.target(forAction: #selector(NSText.paste(_:))) as AnyObject? === editor)
        let board = NSPasteboard.general
        // 元のクリップボードはメモリ内にのみ保持して復元。ログには内容を出さない。
        let saved = (board.pasteboardItems ?? []).map { item -> NSPasteboardItem in
            let copy = NSPasteboardItem()
            for type in item.types {
                if let data = item.data(forType: type) { copy.setData(data, forType: type) }
            }
            return copy
        }
        defer {
            board.clearContents()
            if !saved.isEmpty { board.writeObjects(saved) }
        }
        let dummy = "UNIENTER-DUMMY-PASTE-TEST"
        board.clearContents()
        board.setString(dummy, forType: .string)
        let commandV = try XCTUnwrap(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: .command, timestamp: 0, windowNumber: window.windowNumber, context: nil, characters: "v", charactersIgnoringModifiers: "v", isARepeat: false, keyCode: 9))

        // 旧版のメニュー無し構成では、入力欄自体は⌘Vを処理しない。
        NSApp.mainMenu = nil
        XCTAssertFalse(editor.performKeyEquivalent(with: commandV))
        XCTAssertTrue(editor.string.isEmpty)

        // 右クリックで生成される標準メニューの Paste アクションを実行する。
        let rightClick = try XCTUnwrap(NSEvent.mouseEvent(with: .rightMouseDown, location: .zero, modifierFlags: [], timestamp: 0, windowNumber: window.windowNumber, context: nil, eventNumber: 0, clickCount: 1, pressure: 1))
        let context = try XCTUnwrap(editor.menu(for: rightClick))
        let pasteIndex = context.items.firstIndex { $0.action == #selector(NSText.paste(_:)) }
        context.update()
        context.performActionForItem(at: try XCTUnwrap(pasteIndex))
        XCTAssertEqual(editor.string, dummy)
        editor.selectAll(nil)
        editor.insertText("", replacementRange: editor.selectedRange())

        NSApp.mainMenu = ApplicationMenu.makeMainMenu()
        NSApp.mainMenu?.update()
        XCTAssertTrue(try XCTUnwrap(NSApp.mainMenu).performKeyEquivalent(with: commandV))
        XCTAssertEqual(editor.string, dummy)
        // フォーカス移動で SwiftUI の binding にも反映されることを確認。
        window.makeFirstResponder(nil)
        XCTAssertEqual(model.keyInput, dummy)
        XCTAssertNil(model.message)
    }

    func testEditingKeysAlwaysPassThroughRemapper() {
        let engine = RemapEngine()
        engine.isEnabled = true
        for target in [false, true] {
            for japanese in [false, true] {
                for physical in [false, true] {
                    engine.isTargetAppActive = target
                    engine.isJapaneseMode = japanese
                    for key: Int64 in [9, 8, 7, 0] {
                        XCTAssertEqual(engine.keyDown(keycode: key, mods: [.command], isPhysical: physical), .passThrough)
                        XCTAssertEqual(engine.keyUp(keycode: key, mods: [.command]), .passThrough)
                    }
                }
            }
        }
    }
}
