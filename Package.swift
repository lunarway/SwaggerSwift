// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SwaggerSwift",
    platforms: [.macOS(.v10_15)],
    products: [.executable(name: "swaggerswift", targets: ["SwaggerSwift"])],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "0.4.3"),
        .package(url: "https://github.com/lunarway/SwaggerSwiftML", from: "1.0.10"),
    ],
    targets: [
        .target(
            name: "SwaggerSwift", dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "SwaggerSwiftML", package: "SwaggerSwiftML"),
            ]),
        .testTarget(
            name: "SwaggerSwiftTests",
            dependencies: ["SwaggerSwift"]),
    ]
)
