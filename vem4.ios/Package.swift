// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "VipleEtMoi",
    defaultLocalization: "fr",
    platforms: [
        .iOS(.v18)
    ],
    products: [
        .library(
            name: "VipleEtMoi",
            targets: ["VipleEtMoi"]
        )
    ],
    targets: [
        .target(
            name: "VipleEtMoi",
            path: "Sources"
        )
    ]
)
