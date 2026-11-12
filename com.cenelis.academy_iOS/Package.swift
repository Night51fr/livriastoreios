// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CenelisAcademy",
    defaultLocalization: "fr",
    platforms: [
        .iOS(.v18)
    ],
    products: [
        .library(
            name: "CenelisAcademy",
            targets: ["CenelisAcademy"]
        )
    ],
    targets: [
        .target(
            name: "CenelisAcademy",
            path: "Sources"
        )
    ]
)
