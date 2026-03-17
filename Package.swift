// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SwaggerSwift",
    platforms: [.macOS(.v12)],
    products: [.executable(name: "swaggerswift", targets: ["SwaggerSwift"])],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.5.0"),
        .package(url: "https://github.com/jpsim/Yams.git", from: "6.2.1"),
        .package(url: "https://github.com/stencilproject/Stencil.git", from: "0.15.1"),
    ],
    targets: [
        .executableTarget(
            name: "SwaggerSwift",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                "SwaggerSwiftCore",
            ]
        ),
        .target(
            name: "SwaggerSwiftML",
            dependencies: [
                .product(name: "Yams", package: "Yams")
            ]
        ),
        .target(
            name: "SwaggerSwiftCore",
            dependencies: [
                "SwaggerSwiftML",
                .product(name: "Yams", package: "Yams"),
                .product(name: "Stencil", package: "Stencil"),
            ],
            resources: [
                .copy("Templates")
            ]
        ),
        .testTarget(
            name: "SwaggerSwiftMLTests",
            dependencies: ["SwaggerSwiftML"],
            resources: [
                .copy("BasicSwagger.yaml"),
                .copy("Parameter"),
                .copy("Schemas"),
                .copy("Path"),
                .copy("Items"),
                .copy("Operation"),
                .copy("Response"),
            ]
        ),
        .testTarget(
            name: "SwaggerSwiftCoreTests",
            dependencies: ["SwaggerSwiftCore"],
            exclude: ["Fixtures"]
        ),
    ]
)
