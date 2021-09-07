import Foundation
import SwaggerSwiftML

/// Represents some kind of network model. This could be a response type or a request type.
struct Model {
    let description: String?
    let typeName: String
    let fields: [ModelField]
    let inheritsFrom: [String]
    let isInternalOnly: Bool
    let embeddedDefinitions: [ModelDefinition]

    func resolveInherits(_ definitions: [Model]) -> Model {
        let inherits = inheritsFrom.compactMap { definitionName in
            definitions.first(where: { $0.typeName == definitionName })
        }

        let inheritedFields = inherits.flatMap { $0.fields }
        return Model(description: description,
                     typeName: typeName,
                     fields: (fields + inheritedFields).sorted(by: { $0.name < $1.name }),
                     inheritsFrom: inheritsFrom,
                     isInternalOnly: isInternalOnly,
                     embeddedDefinitions: embeddedDefinitions)
    }

    func modelDefinition(serviceName: String?, swaggerFile: SwaggerFile) -> String {
        let comment: String?
        if let description = description {
            comment = description.split(separator: "\n").map {
                "// \($0)"
            }.joined(separator: "\n")
        } else {
            comment = nil
        }

        let initMethod = """
public init(\(fields.map { "\($0.name): \($0.type.toString(required: $0.required))" }.joined(separator: ", "))) {
    \(fields.map { "self.\($0.name) = \($0.name)" }.joined(separator: "\n    "))
}
"""

        let modelFields = fields.sorted(by: { $0.name < $1.name }).flatMap { $0.toSwift.split(separator: "\n") }

        var model = ""

        if let comment = comment {
            model += comment + "\n"
        }

        model += "public struct \(typeName)\(inheritsFrom.count > 0 ? ": \(inheritsFrom.joined(separator: ", "))" : "") {\n"

        model += modelFields.map { $0 }.joined(separator: "\n").indentLines(1)

        model += "\n\n" + initMethod.indentLines(1)

        if embeddedDefinitions.count > 0 {
            model += "\n\n"
        }

        model += embeddedDefinitions
            .sorted(by: { $0.typeName < $1.typeName })
            .map { $0.toSwift(serviceName: serviceName, swaggerFile: swaggerFile, embedded: true) }
            .joined(separator: "\n\n")
            .indentLines(1)

        model += "\n}"

        return model
    }
}

extension Model: Swiftable {
    func toSwift(serviceName: String?, swaggerFile: SwaggerFile, embedded: Bool) -> String {
        if embedded {
            return modelDefinition(serviceName: serviceName, swaggerFile: swaggerFile)
        }

        var model = "import Foundation\n\n"

        if isInternalOnly {
            model += "#if DEBUG\n"
        }

        let isInExtension = serviceName != nil

        if let serviceName = serviceName {
            model += "extension \(serviceName) {\n"
        }

        model += modelDefinition(serviceName: serviceName, swaggerFile: swaggerFile).indentLines(isInExtension ? 1 : 0)

        if let _ = serviceName {
            model += "\n}"
        }

        if isInternalOnly {
            model += "#endif\n"
        }

        return model
    }
}
