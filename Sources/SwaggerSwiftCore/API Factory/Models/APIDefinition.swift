import Foundation
import SwaggerSwiftML

/// Represent the overall service definition with all the network request methods and the primary initialiser
struct APIDefinition {
    let serviceName: String
    let description: String?
    let fields: [APIDefinitionField]
    let functions: [APIRequest]

    func toSwift(
        swaggerFile: SwaggerFile,
        accessControl: String,
        packagesToImport: [String],
        templateRenderer: TemplateRenderer
    ) throws -> String {
        let initMethod = """
            /// Create an instance of \(serviceName)
            /// - Parameters:
            \(fields.map { $0.documentationString }.joined(separator: "\n"))
            \(accessControl) init(\(fields.map { $0.initProperty }.joined(separator: ", "))) {
            \(fields.map { $0.initAssignment }.joined(separator: "\n").indentLines(1))
            }
            """

        let properties =
            fields
            .map {
                "private let \($0.name): \($0.typeIsBlock ? "@Sendable " : "")\($0.typeName)\($0.isRequired ? "" : "?")"
            }
            .joined(separator: "\n")

        let apiFunctions = self.functions
            .sorted(by: { $0.functionName < $1.functionName })
            .map {
                $0.toSwift(
                    serviceName: serviceName,
                    swaggerFile: swaggerFile,
                    embedded: false,
                    accessControl: accessControl,
                    packagesToImport: packagesToImport
                )
            }.joined(separator: "\n")
            .trimmingCharacters(in: CharacterSet.newlines)

        var context: [String: Any] = [
            "serviceName": serviceName,
            "accessControl": accessControl,
            "packagesToImport": packagesToImport,
            "properties": properties,
            "initMethod": initMethod,
            "apiFunctions": apiFunctions,
        ]
        if let description { context["description"] = description }

        return try templateRenderer.render(template: "APIDefinition.stencil", context: context)
    }
}
