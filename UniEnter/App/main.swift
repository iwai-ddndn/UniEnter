import AppKit

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
app.mainMenu = ApplicationMenu.makeMainMenu()
let delegate = AppDelegate()
app.delegate = delegate
app.run()
