// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "FRYHTMLEditor",
    platforms: [
        .iOS(.v14)
    ],
    products: [
        .library(
            name: "FRYHTMLEditor",
            targets: ["FRYHTMLEditor"]),
    ],
    targets: [
        .target(
            name: "FRYHTMLEditor",
            sources: ["Classes"],
            resources: [.process("Resources")]),
        .testTarget(
            name: "FRYHTMLEditorTests",
            dependencies: ["FRYHTMLEditor"]),
    ]
)
