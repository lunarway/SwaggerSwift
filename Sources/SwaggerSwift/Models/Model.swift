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

    func resolveInherits(_ definitions: [Model]) -> Model {
        let inherits = inheritsFrom.compactMap { definitionName in
            definitions.first(where: { $0.typeName == definitionName })
        }

        let inheritedFields = inherits.flatMap { $0.fields }
        return Model(description: description,
                     typeName: typeName,
                     fields: (fields + inheritedFields).sorted(by: { $0.safePropertyName < $1.safePropertyName }),
                     inheritsFrom: [],
                     isInternalOnly: isInternalOnly,
                     embeddedDefinitions: embeddedDefinitions,
                     isCodable: isCodable)
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

        let initParameterStrings: [String] = fields.map { field in
            let defaultArg: String
            if let defaultValue = field.defaultValue {
                defaultArg = " = " + defaultValue
            } else {
                defaultArg = ""
            }

            let fieldType = "\(field.type.toString(required: field.required || field.defaultValue != nil))"

            if field.needsArgumentLabel {
                return "\(field.argumentLabel) \(field.safeParameterName): \(fieldType)\(defaultArg)"
            } else {
                return "\(field.safeParameterName): \(fieldType)\(defaultArg)"
            }
        }

        let initMethod = """
public init(\(initParameterStrings.joined(separator: ", "))) {
    \(fields.map { "self.\($0.safePropertyName) = \($0.safeParameterName)" }.joined(separator: "\n    "))
}
"""

        let modelFields = fields.sorted(by: { $0.safePropertyName < $1.safePropertyName }).flatMap { $0.toSwift.split(separator: "\n") }

        var model = ""

        if let comment = comment {
            model += comment + "\n"
        }

        model += "public struct \(typeName)\(isCodable ? ": Codable" : "") {\n"

        model += modelFields.map { $0 }.joined(separator: "\n").indentLines(1)

        model += "\n\n" + initMethod.indentLines(1)

        if isCodable && fields.contains(where: { $0.defaultValue != nil }) {
            model += "\n\n"
            model += encodeFunction().indentLines(1)
        }

        if embeddedDefinitions.count > 0 {
            model += "\n\n"
        }

        model += embeddedDefinitions
            .sorted(by: { $0.typeName < $1.typeName })
            .map { $0.toSwift(serviceName: serviceName, swaggerFile: swaggerFile, embedded: true, packagesToImport: []) }
            .joined(separator: "\n\n")
            .indentLines(1)

        model += "\n}"

        return model
    }

    private func encodeFunction() -> String {
        let decodeFields = fields.map {
            "self.\($0.safePropertyName) = try container.decode\($0.required ? "" : "IfPresent")(\($0.type.toString(required: true)).self, forKey: .\($0.safePropertyName))\($0.required == false && $0.defaultValue != nil ? " ?? \($0.defaultValue!)" : "")"
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

extension Model: Swiftable {
    func toSwift(serviceName: String?, swaggerFile: SwaggerFile, embedded: Bool, packagesToImport: [String]) -> String {
        precondition(inheritsFrom.count == 0)

        let isInExtension = serviceName != nil

        if embedded {
            return modelDefinition(serviceName: serviceName, swaggerFile: swaggerFile)
        }

        var model = ""
        model.appendLine("import Foundation")
        model.appendLine()

        if isInternalOnly {
            model.appendLine("#if DEBUG")
            model.appendLine()
        }

        if let serviceName = serviceName {
            model.appendLine("extension \(serviceName) {")
        }

        model += modelDefinition(serviceName: serviceName, swaggerFile: swaggerFile).indentLines(isInExtension ? 1 : 0)

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

extension String {
    mutating func appendLine(_ str: String = "") {
        self += str + "\n"
    }
}
