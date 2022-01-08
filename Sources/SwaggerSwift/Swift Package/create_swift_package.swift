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
    private var targets: [Target]
    
    init(projectName: String, platforms: String, products: [Product] = [], targets: [Target] = []) {
        self.projectName = projectName
        self.platforms = platforms
        self.products = products
        self.targets = targets
    }
    
    func addTarget(_ target: Target) {
        targets.append(target)
    }
    
    func buildPackageFile() -> String {
        let productsLine = products.map { ".library(name: \"\($0.name)\", targets: [\($0.targets.map( { "\"\($0.name)\"" } ).joined(separator: ",\n"))])" }.joined(separator: ",\n")
        let targetsLine = targets.map { ".\($0.type.rawValue)(name: \"\($0.name)\", dependencies:[\($0.dependencies.joined(separator: ","))], path: \"\($0.name)/\")" }.joined(separator: ",\n")
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
            // Targets are the basic building blocks of a package. A target can define a module or a test suite.
            // Targets can depend on other targets in this package, and on products in packages which this package depends on.
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

func createSwiftProject(at path: String, named name: String, targets: [String] = [], fileManager: FileManager = FileManager.default) throws -> (String, String, String) {

    let sharedTargetName = "\(name)Shared"
    let products = targets.reduce(into: [SwiftPackageBuilder.Product(name: "\(name)Shared", targets: [SwiftPackageBuilder.Target(type: .target, name: sharedTargetName, dependencies: [])])], { acc, name in
        acc.append(SwiftPackageBuilder.Product(name: name, targets: [SwiftPackageBuilder.Target(type: .target, name: name, dependencies: [sharedTargetName])]))
    })
    
    let packageBuilder = SwiftPackageBuilder(projectName: name, platforms: "", products: products)
    
    packageBuilder.addTarget(SwiftPackageBuilder.Target(type: .target, name: sharedTargetName, dependencies: []))
    targets.forEach { target in
        let line = ".target(name: \"\(sharedTargetName)\")"
        packageBuilder.addTarget(SwiftPackageBuilder.Target(type: .target, name: target, dependencies: ["\(line)"] ))
    }
    
    let packageFile = packageBuilder.buildPackageFile()

    let expandPath = path.replacingOccurrences(of: "~", with: NSHomeDirectory())
    try packageFile
        .replacingOccurrences(of: "PROJECT_NAME", with: name)
        .write(toFile: expandPath + "/Package.swift", atomically: true, encoding: .utf8)

    return ("", "/Tests", sharedTargetName)
}

