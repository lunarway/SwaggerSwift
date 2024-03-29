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
    let isCodable: Bool

    func resolveInheritanceTree(withModels models: [Model]) -> Model {
        let inherits = inheritsFrom.compactMap { definitionName in
            models.first(where: { $0.typeName == definitionName })
        }

        let inheritedFields = inherits.flatMap { $0.fields }
        let inheritedEmbeddedDefinitions = inherits.flatMap { $0.embeddedDefinitions }

        return Model(description: description,
                     typeName: typeName,
                     fields: (fields + inheritedFields).sorted(by: { $0.safePropertyName < $1.safePropertyName }),
                     inheritsFrom: [],
                     isInternalOnly: isInternalOnly,
                     embeddedDefinitions: embeddedDefinitions + inheritedEmbeddedDefinitions,
                     isCodable: isCodable)
    }

    func modelDefinition(serviceName: String?, accessControl: APIAccessControl) -> String {
        let comment: String?
        if let description = description {
            comment = description.split(separator: "\n").map {
                "// \($0)"
            }.joined(separator: "\n")
        } else {
            comment = nil
        }

        let initMethod = """
\(accessControl.rawValue) init(\(fields.asInitParameter())) {
    \(fields.map { "self.\($0.safePropertyName.value.variableNameFormatted) = \($0.safeParameterName.value.variableNameFormatted)" }.joined(separator: "\n    "))
}
"""

        var model = ""

        if let comment = comment {
            model += comment + "\n"
        }

        model += "\(accessControl.rawValue) struct \(typeName)\(isCodable ? ": Codable, Sendable" : ": Sendable") {\n"

        model += fields.asPropertyList(accessControl: accessControl).indentLines(1)

        model += "\n\n" + initMethod.indentLines(1)

        let fieldsChangesSwaggerFieldNames = fields.contains(where: { $0.usesSwaggerFieldName == false })
        let fieldHasDefaultValue = fields.contains(where: { $0.defaultValue != nil })
        let fieldHasOptionalURL = fields.contains(where: { $0.type.toString(required: true) == "URL" && !$0.isRequired })

        if isCodable && (fieldsChangesSwaggerFieldNames || fieldHasDefaultValue || fieldHasOptionalURL) {
            model += "\n\n"
            model += decodeFunction().indentLines(1)
        }

        if isCodable && fieldsChangesSwaggerFieldNames {
            model += "\n\n"
            model += codingKeysFunction().indentLines(1)
        }

        if embeddedDefinitions.count > 0 {
            model += "\n\n"
        }

        model += embeddedDefinitions
            .sorted(by: { $0.typeName < $1.typeName })
            .map { $0.toSwift(serviceName: serviceName, embedded: true, accessControl: accessControl, packagesToImport: []) }
            .joined(separator: "\n\n")
            .indentLines(1)

        model += "\n}"

        return model
    }

    private func codingKeysFunction() -> String {
        let cases = fields.map { "case \($0.safeParameterName.value.variableNameFormatted) = \"\($0.argumentLabel)\"" }.joined(separator: "\n").indentLines(1)

        return """
        enum CodingKeys: String, CodingKey {
        \(cases)
        }
        """
    }

    private func decodeFunction() -> String {
        let decodeFields = fields.map {
            let variableName = $0.safePropertyName.value.variableNameFormatted
            let typeName = $0.type.toString(required: true)
            let decodeIfPresent: String
            if $0.isRequired == false || $0.defaultValue != nil {
                decodeIfPresent = "IfPresent"
            } else {
                decodeIfPresent = ""
            }

            let defaultValue: String
            if let defaultValueValue = $0.defaultValue {
                defaultValue = " ?? \(defaultValueValue)"
            } else {
                defaultValue = ""
            }

            if !$0.isRequired, typeName == "URL" {
                return """
            // Allows the backend to return badly formatted urls
            if let urlString = try container.decode\(decodeIfPresent)(String.self, forKey: .\(variableName))\(defaultValue) {
                self.\(variableName) = URL(string: urlString)
            } else {
                self.\(variableName) = nil
            }
            """
            } else {
                return "self.\(variableName) = try container.decode\(decodeIfPresent)(\(typeName).self, forKey: .\(variableName))\(defaultValue)"
            }
        }.joined(separator: "\n")

        let functionBody = """
let container = try decoder.container(keyedBy: CodingKeys.self)
\(decodeFields)
"""

        return """
public init(from decoder: Decoder) throws {
\(functionBody.indentLines(1))
}
"""
    }
}

extension Model {
    func toSwift(serviceName: String?, embedded: Bool, accessControl: APIAccessControl, packagesToImport: [String]) -> String {
        precondition(inheritsFrom.count == 0)

        let isInExtension = serviceName != nil

        if embedded {
            return modelDefinition(serviceName: serviceName, accessControl: accessControl)
        }

        var model = ""
        model.appendLine("import Foundation")
        packagesToImport.forEach { model.appendLine("import \($0)") }
        model.appendLine()

        if isInternalOnly {
            model.appendLine("#if DEBUG")
            model.appendLine()
        }

        if let serviceName = serviceName {
            model.appendLine("extension \(serviceName) {")
        }

        model += modelDefinition(serviceName: serviceName, accessControl: accessControl).indentLines(isInExtension ? 1 : 0)

        if let _ = serviceName {
            model.appendLine()
            model.appendLine("}")
        }

        if isInternalOnly {
            model.appendLine()
            model.appendLine("#endif")
        }

        return model
    }
}
