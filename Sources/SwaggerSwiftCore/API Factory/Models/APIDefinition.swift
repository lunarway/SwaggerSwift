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
        let apiFunctions = try self.functions
            .sorted(by: { $0.functionName < $1.functionName })
            .map {
                try $0.toSwift(
                    serviceName: serviceName,
                    swaggerFile: swaggerFile,
                    embedded: false,
                    accessControl: accessControl,
                    packagesToImport: packagesToImport,
                    templateRenderer: templateRenderer
                )
            }.joined(separator: "\n")
            .trimmingCharacters(in: CharacterSet.newlines)

        var context: [String: Any] = [
            "serviceName": serviceName,
            "accessControl": accessControl,
            "packagesToImport": packagesToImport,
            "fields": fields.map(\.templateContext),
            "apiFunctions": apiFunctions,
        ]

        if let description { context["description"] = description }

        return try templateRenderer.render(template: "APIDefinition.stencil", context: context)
    }
}
