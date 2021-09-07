import SwaggerSwiftML

/// Represents some kind of network model. This could be a response type or a request type.
struct Interface {
    let description: String?
    let typeName: String
    let fields: [ModelField]
    let inheritsFrom: [String]
}

extension Interface: Swiftable {
    func toSwift(serviceName: String?, swaggerFile: SwaggerFile, embedded: Bool) -> String {
        let comment = description != nil && description!.count > 0 ? "\n\(defaultSpacing)// \(description ?? "")" : ""

        return """
import Foundation

extension \(serviceName!) {\(comment)
    protocol \(typeName): \((inheritsFrom + ["Codable"]).joined(separator: ", ")) {
\(fields.sorted(by: { $0.name < $1.name }).map { $0.toSwift.split(separator: "\n") }.flatMap { Array($0) }.map { "\(defaultSpacing)\(defaultSpacing)\($0)" }.joined(separator: "\n"))
    }
}
"""
    }
}
