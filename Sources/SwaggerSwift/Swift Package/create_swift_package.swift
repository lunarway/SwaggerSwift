import Foundation

func createSwiftProject(at path: String, named name: String, fileManager: FileManager = FileManager.default) throws -> (String, String) {
    let expandPath = path.replacingOccurrences(of: "~", with: NSHomeDirectory())
    let sourceDirectory = expandPath + "/Sources/\(name)"
    let testsDirectory = expandPath + "/Tests/\(name)Tests"

    try fileManager.createDirectory(atPath: testsDirectory,
                                    withIntermediateDirectories: true,
                                    attributes: nil)

    try fileManager.createDirectory(atPath: sourceDirectory,
                                    withIntermediateDirectories: true,
                                    attributes: nil)

    // create package file
    let packageFile = """
    // swift-tools-version:5.5
    // The swift-tools-version declares the minimum version of Swift required to build this package.

    import PackageDescription

    let package = Package(
        name: "PROJECT_NAME",
        platforms: [.iOS(.v11)],
        products: [
            .library(name: "PROJECT_NAME",
                     targets: ["PROJECT_NAME"]),
            .library(name: "PROJECT_NAMEStatic",
                     type: .static,
                     targets: ["PROJECT_NAME"]),
            .library(name: "PROJECT_NAMEDynamic",
                     type: .dynamic,
                     targets: ["PROJECT_NAME"])
        ],
        targets: [
            .target(name: "PROJECT_NAME"),
            .testTarget(
                name: "PROJECT_NAMETests",
                dependencies: ["PROJECT_NAME"]),
        ]
    )

    """

    try packageFile
        .replacingOccurrences(of: "PROJECT_NAME", with: name)
        .write(toFile: expandPath + "/Package.swift", atomically: true, encoding: .utf8)

    return (sourceDirectory, testsDirectory)
}
