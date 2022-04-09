// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SwaggerSwift",
    platforms: [.macOS(.v12)],
    products: [.executable(name: "swaggerswift", targets: ["SwaggerSwift"])],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", .upToNextMajor(from: "1.1.1")),
        .package(url: "https://github.com/lunarway/SwaggerSwiftML", from: "1.0.16")
//        .package(name: "SwaggerSwiftML", path: "/Users/madsbogeskov/Developer/lunar/swaggerswiftml")
    ],
    targets: [
        .executableTarget(
            name: "SwaggerSwift",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                "SwaggerSwiftCore"
            ]),
        .target(
            name: "SwaggerSwiftCore", dependencies: [
                .product(name: "SwaggerSwiftML", package: "SwaggerSwiftML")
            ]),
        .testTarget(
            name: "SwaggerSwiftCoreTests",
            dependencies: ["SwaggerSwift"])
    ]
)
