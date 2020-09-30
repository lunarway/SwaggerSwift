import Foundation

func createSwiftProject(at path: String, named name: String, fileManager: FileManager = FileManager.default) throws -> String {
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
    // swift-tools-version:5.3
    // The swift-tools-version declares the minimum version of Swift required to build this package.

    import PackageDescription

    let package = Package(
        name: "PROJECT_NAME",
        platforms: [.iOS(.v11)],
        dependencies: [],
        targets: [
            // Targets are the basic building blocks of a package. A target can define a module or a test suite.
            // Targets can depend on other targets in this package, and on products in packages which this package depends on.
            .target(
                name: "PROJECT_NAME",
                dependencies: []),
            .testTarget(
                name: "PROJECT_NAMETests",
                dependencies: ["PROJECT_NAME"]),
        ]
    )
    """

    try packageFile
        .replacingOccurrences(of: "PROJECT_NAME", with: name)
        .write(toFile: path + "/Package.swift", atomically: true, encoding: .utf8)

    return sourceDirectory
}
