// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "KagiAssistantCore",
    platforms: [.iOS(.v16), .macOS(.v12)],
    targets: [
        .target(
            name: "KagiAssistantCore",
            path: "Kagi Assistant",
            sources: ["ContentParser.swift", "Models.swift", "KagiAPI.swift"],
            resources: [.copy("codehilite.css"), .copy("message.css")],
            swiftSettings: [.define("SPM_BUILD")]
        ),
        .testTarget(
            name: "KagiAssistantCoreTests",
            dependencies: ["KagiAssistantCore"],
            path: "Tests"
        ),
    ]
)
