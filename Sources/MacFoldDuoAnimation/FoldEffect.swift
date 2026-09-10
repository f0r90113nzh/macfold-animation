import AppKit
import CoreImage
import ScreenCaptureKit

final class FoldEffect {
    private var overlay: NSWindow?
    private var picture: CALayer?
    private var blurred: CALayer?
    private var blurMask: CAGradientLayer?
    private var lens: CALayer?
    private var lensMask: CAGradientLayer?
    private var lensDistortion: CIFilter?
    private var grain: CALayer?
    private var isCapturing = false
    private var isReady = false
    private var requestedProgress = 0.0
    private var requestedFadeProgress = 0.0

    func captureIfNeeded() {
        guard !isReady, !isCapturing else { return }
        isCapturing = true
        Task { @MainActor [weak self] in
            guard let self else { return }
            defer { self.isCapturing = false }
            do {
                let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
                guard let screen = NSScreen.main,
                      let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID,
                      let display = content.displays.first(where: { $0.displayID == displayID }) else { return }
                let filter = SCContentFilter(display: display, excludingApplications: [], exceptingWindows: [])
                let configuration = SCStreamConfiguration()
                configuration.width = Int(screen.frame.width * screen.backingScaleFactor)
                configuration.height = Int(screen.frame.height * screen.backingScaleFactor)
                configuration.showsCursor = true
                let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration)
                self.makeOverlay(screen: screen, image: image)
                if self.requestedProgress > 0 {
                    self.show(progress: self.requestedProgress, fadeProgress: self.requestedFadeProgress)
                }
            } catch {
                self.isReady = false
            }
        }
    }

    @MainActor
    private func makeOverlay(screen: NSScreen, image: CGImage) {
        overlay?.orderOut(nil)
        let window = NSWindow(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false, screen: screen)
        window.level = .screenSaver
        window.isOpaque = true
        window.backgroundColor = .black
        window.ignoresMouseEvents = true
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]

        let root = CALayer()
        root.frame = CGRect(origin: .zero, size: screen.frame.size)
        root.contentsScale = screen.backingScaleFactor
        root.backgroundColor = NSColor.black.cgColor

        let picture = CALayer()
        picture.frame = root.bounds
        picture.contents = image
        picture.contentsScale = screen.backingScaleFactor
        picture.contentsGravity = .resizeAspectFill
        picture.minificationFilter = .trilinear
        picture.magnificationFilter = .linear
        picture.anchorPoint = CGPoint(x: 0.5, y: 0)
        picture.position = CGPoint(x: root.bounds.midX, y: 0)
        picture.masksToBounds = true
        root.addSublayer(picture)

        let blurred = CALayer()
        blurred.frame = picture.bounds
        blurred.contents = image
        blurred.contentsScale = screen.backingScaleFactor
        blurred.contentsGravity = .resizeAspectFill
        var glassFilters: [CIFilter] = []
        if let blur = CIFilter(name: "CIGaussianBlur") {
            blur.setValue(72, forKey: kCIInputRadiusKey)
            glassFilters.append(blur)
        }
        if let color = CIFilter(name: "CIColorControls") {
            color.setValue(0.55, forKey: kCIInputSaturationKey)
            color.setValue(0.94, forKey: kCIInputContrastKey)
            color.setValue(0.14, forKey: kCIInputBrightnessKey)
            glassFilters.append(color)
        }
        blurred.filters = glassFilters
        let mask = CAGradientLayer()
        mask.frame = blurred.bounds
        mask.contentsScale = screen.backingScaleFactor
        mask.colors = [NSColor.clear.cgColor, NSColor.clear.cgColor, NSColor.white.cgColor]
        mask.locations = [0, 0.30, 1]
        blurred.mask = mask
        blurred.opacity = 0
        picture.addSublayer(blurred)

        let lens = CALayer()
        lens.frame = picture.bounds
        lens.contents = image
        lens.contentsScale = screen.backingScaleFactor
        lens.contentsGravity = .resizeAspectFill
        lens.opacity = 0
        if let distortion = CIFilter(name: "CIBumpDistortionLinear") {
            distortion.setValue(CIVector(x: picture.bounds.midX, y: picture.bounds.height * 0.8), forKey: kCIInputCenterKey)
            distortion.setValue(170, forKey: kCIInputRadiusKey)
            distortion.setValue(0, forKey: kCIInputAngleKey)
            distortion.setValue(0.20, forKey: kCIInputScaleKey)
            lens.filters = [distortion]
            lensDistortion = distortion
        }
        let lensMask = CAGradientLayer()
        lensMask.frame = lens.bounds
        lensMask.colors = [NSColor.clear.cgColor, NSColor.white.cgColor, NSColor.white.cgColor]
        lensMask.locations = [0.78, 0.84, 1]
        lensMask.startPoint = CGPoint(x: 0.5, y: 0)
        lensMask.endPoint = CGPoint(x: 0.5, y: 1)
        lens.mask = lensMask

        let milk = CALayer()
        milk.frame = lens.bounds
        milk.backgroundColor = NSColor.white.withAlphaComponent(0.13).cgColor
        lens.addSublayer(milk)

        let grain = CALayer()
        grain.frame = lens.bounds
        grain.contentsScale = screen.backingScaleFactor
        grain.opacity = 0
        grain.compositingFilter = "softLightBlendMode"
        let noiseExtent = CGRect(
            x: 0,
            y: 0,
            width: screen.frame.width * screen.backingScaleFactor,
            height: screen.frame.height * screen.backingScaleFactor
        )
        if let randomImage = CIFilter(name: "CIRandomGenerator")?.outputImage {
            let noise = randomImage.applyingFilter("CIColorControls", parameters: [
                kCIInputSaturationKey: 0,
                kCIInputContrastKey: 1.65,
                kCIInputBrightnessKey: 0.04
            ]).applyingFilter("CIGaussianBlur", parameters: [
                kCIInputRadiusKey: 0.65
            ])
            if let noiseImage = CIContext(options: [.useSoftwareRenderer: false]).createCGImage(noise, from: noiseExtent) {
                grain.contents = noiseImage
                grain.contentsGravity = .resizeAspectFill
            }
        }
        lens.addSublayer(grain)
        picture.addSublayer(lens)

        let view = NSView(frame: root.bounds)
        view.wantsLayer = true
        view.layer = root
        window.contentView = view
        window.orderOut(nil)
        self.overlay = window
        self.picture = picture
        self.blurred = blurred
        self.blurMask = mask
        self.lens = lens
        self.lensMask = lensMask
        self.grain = grain
        isReady = true
    }

    func show(progress raw: Double, fadeProgress rawFade: Double) {
        requestedProgress = max(0, min(1, raw))
        requestedFadeProgress = max(0, min(1, rawFade))
        guard isReady, let picture else { captureIfNeeded(); return }
        let value = 1 - pow(1 - requestedProgress, 2)
        let fadeValue = 1 - pow(1 - requestedFadeProgress, 2)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        var perspective = CATransform3DIdentity
        perspective.m34 = -1 / 820
        perspective = CATransform3DRotate(
            perspective,
            -CGFloat(value) * .pi * 0.38,
            1,
            0,
            0
        )
        picture.transform = perspective
        picture.opacity = 1
        blurred?.opacity = Float(min(0.68, fadeValue * 0.82))
        lens?.opacity = Float(min(0.72, fadeValue * 0.90))
        grain?.opacity = Float(min(0.34, fadeValue * 0.44))
        if let bounds = overlay?.contentView?.bounds {
            let coverage = min(1, 0.16 + fadeValue * 0.84)
            let boundary = 1 - coverage
            let feather = min(0.12, 72 / max(1, bounds.height))
            let locations = [
                NSNumber(value: Double(max(0, boundary - feather))),
                NSNumber(value: Double(boundary)),
                NSNumber(value: 1)
            ]
            blurMask?.locations = locations
            lensMask?.locations = locations
            lensDistortion?.setValue(
                CIVector(x: bounds.midX, y: bounds.height * CGFloat(boundary)),
                forKey: kCIInputCenterKey
            )
            lensDistortion?.setValue(0.10 + fadeValue * 0.18, forKey: kCIInputScaleKey)
            lens?.setNeedsDisplay()
        }
        CATransaction.commit()
        overlay?.orderFrontRegardless()
    }

    func dismiss() {
        overlay?.orderOut(nil)
        overlay = nil
        picture = nil
        blurred = nil
        blurMask = nil
        lens = nil
        lensMask = nil
        lensDistortion = nil
        grain = nil
        isReady = false
        requestedProgress = 0
        requestedFadeProgress = 0
    }
}
