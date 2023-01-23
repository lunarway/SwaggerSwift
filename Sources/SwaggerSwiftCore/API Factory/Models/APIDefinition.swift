import Foundation
import SwaggerSwiftML

/// Represent the overall service definition with all the network request methods and the primary initialiser
struct APIDefinition {
    let serviceName: String
    let description: String?
    let fields: [APIDefinitionField]
    let functions: [APIRequest]

    func toSwift(swaggerFile: SwaggerFile, accessControl: String, packagesToImport: [String]) -> String {
        let importStatements = (["Foundation"]  + packagesToImport).map { "import \($0)" }.joined(separator: "\n")

        let initMethod = """
/// Create an instance of \(serviceName)
/// - Parameters:
\(fields.map { $0.documentationString }.joined(separator: "\n"))
\(accessControl) init(\(fields.map { $0.initProperty }.joined(separator: ", "))) {
\(fields.map { $0.initAssignment }.joined(separator: "\n").indentLines(1))
}
""".indentLines(1)

        var serviceDefinition = "\(importStatements)\n\n"

        if let description = description {
            serviceDefinition.append("// \(description)\n")
        }

        let properties = fields
            .map { "private let \($0.name): \($0.typeName)\($0.isRequired ? "" : "?")" }
            .joined(separator: "\n")
            .indentLines(1)

        let apiFunctions = self.functions
            .sorted(by: { $0.functionName < $1.functionName })
            .map {
                $0.toSwift(serviceName: serviceName,
                           swaggerFile: swaggerFile,
                           embedded: false,
                           accessControl: accessControl,
                           packagesToImport: packagesToImport)
            }.joined(separator: "\n")
            .indentLines(1)
            .trimmingCharacters(in: CharacterSet.newlines)

        serviceDefinition += """
\(accessControl) struct \(serviceName): @unchecked Sendable, APIInitialize {
\(properties)

\(initMethod)

\(apiFunctions)
}

"""
        return serviceDefinition
    }
}
