import Foundation
import SwaggerSwiftML

/// Represent the overall service definition with all the network request methods and the primary initialiser
struct APIDefinition {
    let serviceName: String
    let description: String?
    let fields: [APIDefinitionField]
    let functions: [APIRequest]

    private static let templateRenderer = TemplateRenderer()

    func toSwift(swaggerFile: SwaggerFile, accessControl: String, packagesToImport: [String])
        -> String
    {
        let importStatements = (["Foundation"] + packagesToImport).map { "import \($0)" }.joined(
            separator: "\n"
        )

        let properties =
            fields
            .map {
                "private let \($0.name): \($0.typeIsBlock ? "@Sendable " : "")\($0.typeName)\($0.isRequired ? "" : "?")"
            }
            .joined(separator: "\n")
            .indentLines(1)

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
            .indentLines(1)
            .trimmingCharacters(in: CharacterSet.newlines)

        let context: [String: Any] = [
            "importStatements": importStatements,
            "hasDescription": description != nil,
            "description": description ?? "",
            "accessControl": accessControl,
            "serviceName": serviceName,
            "properties": properties,
            "initParameterDocumentation": fields.map { $0.documentationString }.joined(separator: "\n"),
            "initProperties": fields.map { $0.initProperty }.joined(separator: ", "),
            "initAssignments": fields.map { $0.initAssignment }.joined(separator: "\n"),
            "apiFunctions": apiFunctions,
        ]

        do {
            return try Self.templateRenderer.render(template: "APIDefinition.stencil", context: context)
        } catch {
            fatalError("Failed to render APIDefinition for \(serviceName): \(error)")
        }
    }
}
