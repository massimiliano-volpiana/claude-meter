// swift-tools-version: 5.7
import PackageDescription

let package = Package(
    name: "ClaudeMeter",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .executable(name: "ClaudeMeter", targets: ["ClaudeMeter"]),
    ],
    targets: [
        .target(
            name: "Shared",
            path: "Sources/Shared"
        ),
        .executableTarget(
            name: "ClaudeMeter",
            dependencies: ["Shared"],
            path: "Sources/ClaudeMeter",
            exclude: [
                "Info.plist",
                "ClaudeMeter.entitlements",
                "Assets.xcassets",
            ],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("ServiceManagement"),
            ]
        ),
    ]
)
