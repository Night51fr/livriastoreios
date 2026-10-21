// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Livria",
    defaultLocalization: "fr",
    platforms: [
        .iOS(.v18)
    ],
    products: [
        .library(
            name: "Livria",
            targets: ["Livria"]
        )
    ],
    targets: [
        .target(
            name: "Livria",
            path: "Sources"
        )
    ]
)
