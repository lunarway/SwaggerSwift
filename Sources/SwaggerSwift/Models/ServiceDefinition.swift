import SwaggerSwiftML

/// Represent the overall service definition with all the network request methods and the primary initialiser
struct ServiceDefinition {
    let typeName: String
    let description: String?
    let fields: [ServiceField]
    let functions: [NetworkRequestFunction]
    let innerTypes: [ModelDefinition]
}

extension ServiceDefinition: Swiftable {
    func toSwift(serviceName: String?, swaggerFile: SwaggerFile, embedded: Bool) -> String {
        let initMethod = """
/// Initialises the service
/// - Parameters:
\(fields.map { "///   - \($0.name): \($0.description ?? "")" }.joined(separator: "\n"))
public init(\(fields.map { "\($0.name): \($0.typeIsAutoclosure ? "@autoclosure " : "")\($0.typeIsBlock ? "@escaping " : "")\($0.typeName)\($0.required ? "" : "?")\($0.defaultValue != nil ? " = \($0.defaultValue!)" : "")" }.joined(separator: ", "))) {
    \(fields.map { "self.\($0.name) = \($0.name)" }.joined(separator: "\n    "))
}
"""

        var serviceDefinition = "import Foundation\n\n"

        if let description = description {
            serviceDefinition.append("// \(description)\n")
        }

        serviceDefinition += """
public struct \(typeName) {
    \(fields.map { "private let \($0.name): \($0.typeName)\($0.required ? "" : "?")" }.joined(separator: "\n    "))

    \(initMethod.replacingOccurrences(of: "\n", with: "\n    "))

    \(self.functions
        .sorted(by: { $0.functionName < $1.functionName })
        .map { $0.toSwift(serviceName: serviceName, swaggerFile:
                            swaggerFile,
                          embedded: false).replacingOccurrences(of: "\n", with: "\n    ") }
        .joined(separator: "\n\n    "))
}

"""
        return serviceDefinition
    }
}
