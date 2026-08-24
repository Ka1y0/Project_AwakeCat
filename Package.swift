// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "AwakeCat",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .library(name: "AwakeCatCore", targets: ["AwakeCatCore"]),
        .executable(name: "AwakeCat", targets: ["AwakeCat"])
    ],
    targets: [
        .target(
            name: "AwakeCatCore",
            linkerSettings: [
                .linkedFramework("IOKit")
            ]
        ),
        .executableTarget(
            name: "AwakeCat",
            dependencies: ["AwakeCatCore"],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("ServiceManagement")
            ]
        ),
        .testTarget(
            name: "AwakeCatCoreTests",
            dependencies: ["AwakeCatCore"]
        )
    ],
    swiftLanguageModes: [.v6]
)
