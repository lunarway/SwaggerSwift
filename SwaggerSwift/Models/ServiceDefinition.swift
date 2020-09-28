/// Represent the overall service definition with all the network request methods and the primary initialiser
struct ServiceDefinition {
    let typeName: String
    let fields: [ServiceField]
    let functions: [NetworkRequestFunction]
    let innerTypes: [ModelDefinition]
}

extension ServiceDefinition: Swiftable {
    func toSwift() -> String {
        return """
import Foundation

struct \(typeName) {
    \(fields.map { "let \($0.name): \($0.typeName)" }.joined(separator: "\n    "))

    \(self.functions
        .sorted(by: { $0.functionName < $1.functionName })
        .map { $0.toSwift().replacingOccurrences(of: "\n", with: "\n    ") }
        .joined(separator: "\n\n    "))
}
"""
    }
}
