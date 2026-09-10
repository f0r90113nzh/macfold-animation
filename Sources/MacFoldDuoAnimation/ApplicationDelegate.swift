import AppKit
import CoreGraphics

final class ApplicationDelegate: NSObject, NSApplicationDelegate {
    private let hinge = HingeReader()
    private let foldEffect = FoldEffect()
    private var statusItem: NSStatusItem!
    private var previousAngle = 180.0
    private var progress = 0.0
    private var startAngle = 80.0
    private var angleValueLabel: NSTextField?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "rectangle.portrait.rotate", accessibilityDescription: "MacFold")
        statusItem.button?.toolTip = "MacFold Duo Animation"

        let menu = NSMenu()
        let sensorState = NSMenuItem(title: hinge.isAvailable ? "Датчик крышки подключён" : "Датчик крышки не найден", action: nil, keyEquivalent: "")
        sensorState.isEnabled = false
        menu.addItem(sensorState)
        menu.addItem(withTitle: "Разрешить запись экрана…", action: #selector(requestCaptureAccess), keyEquivalent: "")
        menu.addItem(makeAngleSliderItem())
        menu.addItem(.separator())
        menu.addItem(withTitle: "Завершить", action: #selector(quit), keyEquivalent: "q")
        statusItem.menu = menu
        UserDefaults.standard.removeObject(forKey: "foldSpeedMultiplier")

        hinge.onAngle = { [weak self] angle in
            self?.receive(angle)
        }
        hinge.start()
    }

    private func makeAngleSliderItem() -> NSMenuItem {
        if let saved = UserDefaults.standard.object(forKey: "startAngle") as? Double {
            startAngle = min(92, max(30, saved))
        }

        let item = NSMenuItem()
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 270, height: 68))
        let title = NSTextField(labelWithString: "Начало эффекта")
        title.frame = NSRect(x: 14, y: 40, width: 180, height: 18)
        let value = NSTextField(labelWithString: "\(Int(startAngle))°")
        value.alignment = .right
        value.frame = NSRect(x: 205, y: 40, width: 50, height: 18)

        let slider = NSSlider(value: startAngle, minValue: 30, maxValue: 92, target: self, action: #selector(startAngleChanged(_:)))
        slider.frame = NSRect(x: 12, y: 8, width: 246, height: 26)
        slider.isContinuous = true
        container.addSubview(title)
        container.addSubview(value)
        container.addSubview(slider)
        angleValueLabel = value
        item.view = container
        return item
    }

    @objc private func startAngleChanged(_ sender: NSSlider) {
        startAngle = sender.doubleValue.rounded()
        sender.doubleValue = startAngle
        angleValueLabel?.stringValue = "\(Int(startAngle))°"
        UserDefaults.standard.set(startAngle, forKey: "startAngle")
        progress = 0
        foldEffect.dismiss()
    }

    @objc private func requestCaptureAccess() {
        if !CGPreflightScreenCaptureAccess() { _ = CGRequestScreenCaptureAccess() }
    }

    private func receive(_ angle: Double) {
        statusItem.button?.toolTip = "MacFold — \(Int(angle.rounded()))°"
        let isClosing = angle < previousAngle - 0.08
        let isOpening = angle > previousAngle + 0.12

        if isClosing, angle < startAngle + 15 { foldEffect.captureIfNeeded() }
        let angularProgress = angle < startAngle ? min(1, max(0, (startAngle - angle) / 83.0)) : 0
        let target = angularProgress * 0.10
        if isClosing || target > 0 {
            progress += (target - progress) * 0.42
            foldEffect.show(progress: progress, fadeProgress: angularProgress)
        } else if isOpening || angle >= startAngle {
            progress = 0
            foldEffect.dismiss()
        }
        previousAngle = angle
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
}
