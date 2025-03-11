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
        let dependencies: [Target]

        init(type: TargetType, name: String, dependencies: [Target] = []) {
            self.type = type
            self.name = name
            self.dependencies = dependencies
        }
    }

    private let projectName: String
    private let platforms: String  // Find better datastructure
    private var products: [Product]

    init(projectName: String, platforms: String, products: [Product] = []) {
        self.projectName = projectName
        self.platforms = platforms
        self.products = products
    }

    func buildPackageFile() -> String {
        let products = self.products.sorted(by: { $0.name < $1.name })

        let productsLine = products.map {
            """
            .library(
                name: \"\($0.name)\",
                targets: [
            \($0.targets.sorted(by: { $0.name < $1.name }).map { "\"\($0.name)\"" }.joined(separator: ",\n").indentLines(2))
                ]
            )
            """
        }.joined(separator: ",\n").indentLines(2)

        let allTargets = products.flatMap { $0.targets }

        let targetsLine =
            allTargets
            .sorted(by: { $0.name < $1.name })
            .map { target in
                """
                .\(target.type.rawValue)(
                    name: \"\(target.name)\",
                    dependencies: [
                \(target.dependencies.map { "\"\($0.name)\"" }.joined(separator: ",").indentLines(2))
                    ]
                )
                """
            }.joined(separator: ",\n").indentLines(2)

        let packageFile =
            """
            // swift-tools-version: 6.0
            // The swift-tools-version declares the minimum version of Swift required to build this package.

            import PackageDescription

            let package = Package(
                name: "PROJECT_NAME",
                platforms: [.iOS(.v15), .macOS(.v12)],
                products: [
            PRODUCTS
                ],
                dependencies: [],
                targets: [
            TARGETS
                ]
            )

            """
        return
            packageFile
            .replacingOccurrences(of: "PROJECT_NAME", with: projectName)
            .replacingOccurrences(of: "PRODUCTS", with: productsLine)
            .replacingOccurrences(of: "TARGETS", with: targetsLine)
    }
}
