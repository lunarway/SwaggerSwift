import Foundation
import SwaggerSwiftML

/// Represents a Swift enum
struct Enumeration {
    let serviceName: String?
    let description: String?
    let typeName: String
    let values: [String]
    let isCodable: Bool
    let collectionFormat: CollectionFormat?

    static func toCasename(_ str: String, _ isCodable: Bool) -> String {
        let str = isCodable ? str.camelized : str

        if SwiftKeyword(rawValue: str) != nil {
            return "`\(str)`"
        }

        if str.isNumber {
            return "_\(str)"
        }

        return str
    }

    func modelDefinition(embeddedFile: Bool, accessControl: APIAccessControl) -> String {
        let valueNames =
            values
            .sorted(by: { $0 < $1 })
            .map { isCodable ? $0.camelized : $0 }
            .map { Self.toCasename($0, isCodable) }

        var cases = valueNames.map { "case \($0)" }

        var unknownName = "unknown"
        if valueNames.contains(unknownName) {
            unknownName = "unknownCase"
        }

        if isCodable {
            cases += ["case \(unknownName)(String)"]
        }

        var model = """
            \(accessControl.rawValue) enum \(self.typeName)\(isCodable ? ": Codable, Equatable, Sendable" : ": Sendable") {
            \(cases.joined(separator: "\n").indentLines(1))
            """
        if isCodable {
            let decodeCases =
                values
                .sorted()
                .map { "case \"\($0)\": self = .\(Self.toCasename($0, isCodable))" }
                .joined(separator: "\n").indentLines(1)

            model += """


                \(accessControl.rawValue) init(from decoder: any Decoder) throws {
                    let container = try decoder.singleValueContainer()
                    let stringValue = try container.decode(String.self)
                    switch stringValue {
                \(decodeCases)
                    default:
                        self = .\(unknownName)(stringValue)
                    }
                }

                """.indentLines(1)

            let encodeCases = values.sorted().map {
                """
                case .\(Self.toCasename($0, isCodable)):
                    try container.encode("\($0)")
                """
            }.joined(separator: "\n").indentLines(1)

            model += """

                \(accessControl.rawValue) func encode(to encoder: any Encoder) throws {
                    var container = encoder.singleValueContainer()
                    switch self {
                \(encodeCases)
                    case .\(unknownName)(let stringValue):
                        try container.encode(stringValue)
                    }
                }
                """.indentLines(1)

            model += "\n"

            model += """

                \(accessControl.rawValue) init(rawValue: String) {
                    switch rawValue {
                \(decodeCases)
                    default:
                        self = .\(unknownName)(rawValue)
                    }
                }
                """.indentLines(1)

            let rawValueCases = values.sorted().map {
                """
                case .\(Self.toCasename($0, isCodable)):
                    return "\($0)"
                """
            }.joined(separator: "\n").indentLines(1)

            model += "\n"

            model += """

                \(accessControl.rawValue) var rawValue: String {
                    switch self {
                \(rawValueCases)
                    case .\(unknownName)(let stringValue):
                        return stringValue
                    }
                }
                """.indentLines(1)
        }

        model += "\n"

        model += "}"

        return model
    }
}

extension Enumeration {
    func toSwift(
        serviceName: String?,
        embedded: Bool,
        accessControl: APIAccessControl,
        packagesToImport: [String],
        templateRenderer: TemplateRenderer
    ) throws -> String {
        let enumBody = modelDefinition(embeddedFile: embedded, accessControl: accessControl)

        let descriptionComment: String? =
            if let description = description, description.count > 0 {
                description.replacingOccurrences(of: "\n", with: "\n// ")
            } else {
                nil
            }

        var context: [String: Any] = [
            "embedded": embedded,
            "packagesToImport": packagesToImport,
            "enumBody": enumBody,
        ]
        if let serviceName { context["serviceName"] = serviceName }
        if let descriptionComment { context["description"] = descriptionComment }

        return try templateRenderer.render(template: "Enumeration.stencil", context: context)
    }
}
