import Foundation
import IOKit.hid

final class HingeReader {
    var onAngle: ((Double) -> Void)?
    private var device: IOHIDDevice?
    private var manager: IOHIDManager?
    private var timer: Timer?
    private var bytes = [UInt8](repeating: 0, count: 8)
    private let options = IOOptionBits(kIOHIDOptionsTypeNone)

    var isAvailable: Bool { device != nil }

    init() {
        let manager = IOHIDManagerCreate(kCFAllocatorDefault, options)
        guard IOHIDManagerOpen(manager, options) == kIOReturnSuccess else { return }
        self.manager = manager
        IOHIDManagerSetDeviceMatching(manager, [
            kIOHIDVendorIDKey as String: 0x05ac,
            kIOHIDDeviceUsagePageKey as String: 0x20,
            kIOHIDDeviceUsageKey as String: 0x8a
        ] as CFDictionary)
        device = (IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice>)?.first
        if let device { IOHIDDeviceOpen(device, options) }
    }

    func start() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 1 / 60, repeats: true) { [weak self] _ in self?.read() }
        if let timer { RunLoop.main.add(timer, forMode: .common) }
    }

    private func read() {
        guard let device else { return }
        var count = CFIndex(bytes.count)
        guard IOHIDDeviceGetReport(device, kIOHIDReportTypeFeature, 1, &bytes, &count) == kIOReturnSuccess,
              count >= 3 else { return }
        let raw = UInt16(bytes[1]) | UInt16(bytes[2]) << 8
        if raw <= 180 { onAngle?(Double(raw)) }
    }
}

