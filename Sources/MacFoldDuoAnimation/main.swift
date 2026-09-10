import AppKit

let application = NSApplication.shared
let applicationDelegate = ApplicationDelegate()
application.delegate = applicationDelegate
application.setActivationPolicy(.accessory)
application.run()

