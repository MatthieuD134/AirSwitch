// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AirSwitch",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "airswitch", targets: ["AirSwitch"]),
        .library(name: "AirSwitchKit", targets: ["AirSwitchKit"])
    ],
    targets: [
        .target(
            name: "AirSwitchKit",
            dependencies: [],
            path: "Sources/AirSwitchKit",
            linkerSettings: [
                .linkedFramework("IOBluetooth"),
                .linkedFramework("AppKit"),
                .linkedFramework("Carbon"),
                .linkedFramework("IOKit"),
                .linkedFramework("ServiceManagement")
            ]
        ),
        .executableTarget(
            name: "AirSwitch",
            dependencies: ["AirSwitchKit"],
            path: "Sources/AirSwitch"
        ),
        .testTarget(
            name: "AirSwitchTests",
            dependencies: ["AirSwitchKit"],
            path: "Tests/AirSwitchTests"
        )
    ]
)
