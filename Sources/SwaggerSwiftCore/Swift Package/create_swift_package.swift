import Foundation

extension SwaggerSwift {
    /// Creates the Package.swift file used in the Swift package
    /// - Parameters:
    ///   - path: the path to the swift package
    ///   - name: the swift package name
    ///   - commonLibraryName: The name of the common library. The common library is a library that contains the common SwaggerSwift files shared between the different API targets.
    ///   - targets: the name of the API targets
    ///   - fileManager: the file manager
    /// - Throws: Throws if the files couldnt be created on disk
    func createPackageSwiftFile(at path: String, named name: String, commonLibraryName: String, apis: [String], fileManager: FileManager = FileManager.default) throws {
        let commonTarget = SwiftPackageBuilder.Target(type: .target, name: commonLibraryName)
        let apiTargets = apis.map {
            SwiftPackageBuilder.Target(
                type: .target,
                name: $0,
                dependencies: [commonTarget]
            )
        }

        var targets = [commonTarget]
        targets.append(contentsOf: apiTargets)

        let product = SwiftPackageBuilder.Product(name: name, targets: targets)
        let packageBuilder = SwiftPackageBuilder(projectName: name, platforms: "", products: [product])

        let packageFile = packageBuilder.buildPackageFile()

        let expandedPath = path.replacingOccurrences(of: "~", with: NSHomeDirectory())
        // create the initial directory
        try fileManager.createDirectory(atPath: expandedPath, withIntermediateDirectories: true)

        // write package swift file
        try packageFile.write(toFile: expandedPath + "/Package.swift", atomically: true, encoding: .utf8)
    }
}
