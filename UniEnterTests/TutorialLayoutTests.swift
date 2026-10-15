import AppKit
import SwiftUI
import XCTest
@testable import UniEnter

final class TutorialLayoutTests: XCTestCase {
    @MainActor
    func testIntroductionFitsSmallMacDisplayWithoutSettingsChoices() {
        let host = NSHostingView(rootView: TutorialView(finish: {}))
        let size = host.fittingSize
        XCTAssertEqual(size.width, 460, accuracy: 1)
        // Leave space for the menu bar, Dock and window title on a 1024×640 desktop.
        XCTAssertLessThan(size.height, 540)
        XCTAssertGreaterThan(size.height, 250)
    }

    @MainActor
    func testReopeningOptionsAndRelaunchPreserveExistingChoices() throws {
        let name = "TutorialLayoutTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let store = SettingsStore(defaults: defaults)
        XCTAssertFalse(store.hasSeenTutorial)
        store.enabledDesktopIDs = ["com.hnc.Discord"]
        store.enabledWebIDs = []
        store.cmdEnterSendApps = ["com.hnc.Discord", "com.ovice.desktop.prod"]
        store.hasSeenTutorial = true
        let snapshot = defaults.persistentDomain(forName: name)! as NSDictionary
        for count in [2, 4, 8] {
            let model = SettingsViewModel(store: SettingsStore(defaults: defaults))
            XCTAssertFalse(model.showAdvanced)
            model.cmdEnterSendApps = Set(AppRegistry.all.filter(\.hasDesktop).prefix(count).map(\.bundleID))
            let host = NSHostingView(rootView: SettingsView(model: model, showAdvanced: true))
            XCTAssertTrue(model.showAdvanced)
            XCTAssertEqual(host.fittingSize.width, 400, accuracy: 1)
            XCTAssertEqual(host.fittingSize.height, 560, accuracy: 1)
            XCTAssertEqual(defaults.persistentDomain(forName: name)! as NSDictionary, snapshot)
        }
        XCTAssertTrue(SettingsStore(defaults: defaults).hasSeenTutorial)
        XCTAssertEqual(SettingsStore(defaults: defaults).cmdEnterSendApps, store.cmdEnterSendApps)
    }
}
