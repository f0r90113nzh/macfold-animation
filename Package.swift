// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "MacFoldDuoAnimation",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "MacFoldDuoAnimation",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("IOKit"),
                .linkedFramework("ScreenCaptureKit")
            ]
        )
    ]
)

