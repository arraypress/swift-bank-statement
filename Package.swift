// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "BankStatement",
    // PDFKit and Foundation only — no UI, so this runs headless. The floor is
    // Swift's `Regex`, which the amount and date parsers are written in.
    platforms: [
        .macOS(.v13),
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "BankStatement",
            targets: ["BankStatement"]
        ),
    ],
    targets: [
        .target(
            name: "BankStatement",
            dependencies: []
        ),
        .testTarget(
            name: "BankStatementTests",
            dependencies: ["BankStatement"]
        ),
    ]
)
