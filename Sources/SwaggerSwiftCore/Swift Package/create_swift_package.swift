import Foundation

class SwiftPackageBuilder {
    struct Product {
        let name: String
        let targets: [Target]
    }
    struct Target {
        enum TargetType: String {
            case target
            case testTarget
        }
        let type: TargetType
        let name: String
        let dependencies: [String]
    }
    private let projectName: String
    private let platforms: String // Find better datastructure
    private var products: [Product]
    
    init(projectName: String, platforms: String, products: [Product] = []) {
        self.projectName = projectName
        self.platforms = platforms
        self.products = products
    }
    
    func buildPackageFile() -> String {
        let productsLine = products.map { ".library(name: \"\($0.name)\", type: .static, targets: [\($0.targets.map( { "\"\($0.name)\"" } ).joined(separator: ",\n"))])" }.joined(separator: ",\n")
        let allTargets = products.flatMap({ $0.targets })
        let targetsLine = allTargets.map { ".\($0.type.rawValue)(name: \"\($0.name)\", dependencies:[\($0.dependencies.map({"\"\($0)\""}).joined(separator: ","))])" }.joined(separator: ",\n")
        let packageFile = """
    // swift-tools-version:5.3
    // The swift-tools-version declares the minimum version of Swift required to build this package.
    
    import PackageDescription
    
    let package = Package(
        name: "PROJECT_NAME",
        platforms: [.iOS(.v12)],
        products: [PRODUCTS],
        dependencies: [],
        targets: [
            TARGETS
        ]
    )

    """
        return packageFile
            .replacingOccurrences(of: "PROJECT_NAME", with: projectName)
            .replacingOccurrences(of: "PRODUCTS", with: productsLine)
            .replacingOccurrences(of: "TARGETS", with: targetsLine)
    }
    
}

func createSwiftProject(at path: String, named name: String, sharedTargetName: String, targets: [String] = [], fileManager: FileManager = FileManager.default) throws {
    let sharedTarget = SwiftPackageBuilder.Target(type: .target, name: sharedTargetName, dependencies: [])
    let serviceTargets = targets.map { SwiftPackageBuilder.Target(type: .target, name: $0, dependencies: [sharedTargetName]) }
    var targets = [sharedTarget]
    targets.append(contentsOf: serviceTargets)
    let product = SwiftPackageBuilder.Product(name: name, targets: targets)
    let packageBuilder = SwiftPackageBuilder(projectName: name, platforms: "", products: [product])

    let packageFile = packageBuilder.buildPackageFile()

    let expandPath = path.replacingOccurrences(of: "~", with: NSHomeDirectory())
    try fileManager.createDirectory(atPath: expandPath, withIntermediateDirectories: true)
    try packageFile
        .replacingOccurrences(of: "PROJECT_NAME", with: name)
        .write(toFile: expandPath + "/Package.swift", atomically: true, encoding: .utf8)
}
