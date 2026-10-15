import AppKit

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
app.mainMenu = ApplicationMenu.makeMainMenu()
// Hosted unit tests must not start a second event tap or request permissions.
#if DEBUG
let isUnitTesting = NSClassFromString("XCTestCase") != nil
    || ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
let delegate: AppDelegate? = isUnitTesting ? nil : AppDelegate()
#else
let delegate = AppDelegate()
#endif
app.delegate = delegate
app.run()
