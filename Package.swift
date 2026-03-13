// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SwaggerSwift",
    platforms: [.macOS(.v12)],
    products: [.executable(name: "swaggerswift", targets: ["SwaggerSwift"])],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.5.0"),
        .package(url: "https://github.com/lunarway/SwaggerSwiftML", from: "3.1.0"),
        .package(url: "https://github.com/jpsim/Yams.git", from: "6.2.1"),
        .package(url: "https://github.com/stencilproject/Stencil.git", from: "0.15.1"),
        .package(url: "https://github.com/SwiftGen/StencilSwiftKit.git", from: "2.10.1"),
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
            name: "SwaggerSwiftCore",
            dependencies: [
                .product(name: "SwaggerSwiftML", package: "SwaggerSwiftML"),
                .product(name: "Yams", package: "Yams"),
                .product(name: "Stencil", package: "Stencil"),
                .product(name: "StencilSwiftKit", package: "StencilSwiftKit"),
            ],
            resources: [
                .copy("Templates"),
            ]
        ),
        .testTarget(
            name: "SwaggerSwiftCoreTests",
            dependencies: ["SwaggerSwiftCore"],
            exclude: ["Fixtures"]
        ),
    ]
)
