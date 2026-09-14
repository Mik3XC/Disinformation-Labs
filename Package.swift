// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "DisinformationWorkshop",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "DisinformationWorkshop", targets: ["DisinformationWorkshop"]),
        .executable(name: "WorkshopChecks", targets: ["WorkshopChecks"])
    ],
    targets: [
        .target(name: "WorkshopCore", resources: [.process("Resources")]),
        .executableTarget(name: "DisinformationWorkshop", dependencies: ["WorkshopCore"]),
        .executableTarget(name: "WorkshopChecks", dependencies: ["WorkshopCore"])
    ]
)
