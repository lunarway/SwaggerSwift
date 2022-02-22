import SwaggerSwiftML

/// Represents some kind of network model. This could be a response type or a request type.
struct Interface {
    let description: String?
    let typeName: String
    let fields: [ModelField]
    let inheritsFrom: [String]
}

extension Interface: Swiftable {
    func toSwift(serviceName: String?, swaggerFile: SwaggerFile, embedded: Bool, packagesToImport: [String]) -> String {
        let comment = description != nil && description!.count > 0 ? "\n\(defaultSpacing)// \(description ?? "")" : ""

        let fieldsString = fields
            .sorted(by: { $0.safePropertyName < $1.safePropertyName })
            .map { $0.toSwift.split(separator: "\n") }
            .map { "\(defaultSpacing)\(defaultSpacing)\($0)" }
            .joined(separator: "\n")

        return """
import Foundation

extension \(serviceName!) {\(comment)
    protocol \(typeName): \((inheritsFrom + ["Codable"]).joined(separator: ", ")) {
\(fieldsString)
    }
}
"""
    }
}
