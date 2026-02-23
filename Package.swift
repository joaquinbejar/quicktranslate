// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "QuickTranslate",
    platforms: [
        .macOS(.v13),
    ],
    targets: [
        .executableTarget(
            name: "QuickTranslate",
            path: "QuickTranslate",
            exclude: ["Info.plist", "QuickTranslate.entitlements", "Assets.xcassets", "Resources"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "QuickTranslateTests",
            dependencies: ["QuickTranslate"],
            path: "QuickTranslateTests",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
