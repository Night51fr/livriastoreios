// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CenelisWorkspace",
    defaultLocalization: "fr",
    platforms: [
        .iOS(.v18)
    ],
    products: [
        .library(
            name: "CenelisWorkspace",
            targets: ["CenelisWorkspace"]
        )
    ],
    targets: [
        .target(
            name: "CenelisWorkspace",
            path: "Sources"
        )
    ]
)
