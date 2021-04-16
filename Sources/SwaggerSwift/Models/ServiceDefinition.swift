/// Represent the overall service definition with all the network request methods and the primary initialiser
struct ServiceDefinition {
    let typeName: String
    let fields: [ServiceField]
    let functions: [NetworkRequestFunction]
    let innerTypes: [ModelDefinition]
}

extension ServiceDefinition: Swiftable {
    func toSwift(swaggerFile: SwaggerFile) -> String {
        let initMethod = """
public init(\(fields.map { "\($0.name): \($0.typeIsBlock ? "@escaping " : "")\($0.typeName)" }.joined(separator: ", "))) {
    \(fields.map { "self.\($0.name) = \($0.name)" }.joined(separator: "\n    "))
}
"""

        return """
import Foundation

public struct \(typeName) {
    \(fields.map { "public let \($0.name): \($0.typeName)" }.joined(separator: "\n    "))

    \(initMethod.replacingOccurrences(of: "\n", with: "\n    "))

    \(self.functions
        .sorted(by: { $0.functionName < $1.functionName })
        .map { $0.toSwift(swaggerFile: swaggerFile).replacingOccurrences(of: "\n", with: "\n    ") }
        .joined(separator: "\n\n    "))
}
"""
    }
}
