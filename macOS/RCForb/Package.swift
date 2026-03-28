// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "RCForb",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "RCForb",
            path: "Sources",
            exclude: ["App/Info.plist"],
            resources: [
                .copy("Fonts"),
                .copy("Images"),
            ],
            linkerSettings: [
                .linkedFramework("AVFoundation"),
                .linkedFramework("Security"),
                .linkedFramework("Network"),
                .linkedFramework("CoreText"),
            ]
        ),
    ]
)
