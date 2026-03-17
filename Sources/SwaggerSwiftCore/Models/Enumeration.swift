import Foundation
import SwaggerSwiftML

/// Represents a Swift enum
struct Enumeration {
    let serviceName: String?
    let description: String?
    let typeName: String
    let values: [String]
    let isEncodable: Bool
    let isDecodable: Bool
    let collectionFormat: CollectionFormat?

    init(
        serviceName: String?,
        description: String?,
        typeName: String,
        values: [String],
        isCodable: Bool,
        collectionFormat: CollectionFormat?
    ) {
        self.init(
            serviceName: serviceName,
            description: description,
            typeName: typeName,
            values: values,
            isEncodable: isCodable,
            isDecodable: isCodable,
            collectionFormat: collectionFormat
        )
    }

    init(
        serviceName: String?,
        description: String?,
        typeName: String,
        values: [String],
        isEncodable: Bool,
        isDecodable: Bool,
        collectionFormat: CollectionFormat?
    ) {
        self.serviceName = serviceName
        self.description = description
        self.typeName = typeName
        self.values = values
        self.isEncodable = isEncodable
        self.isDecodable = isDecodable
        self.collectionFormat = collectionFormat
    }

    var supportsCodableConformanceOptimization: Bool {
        isEncodable || isDecodable
    }

    func withConformance(isEncodable: Bool, isDecodable: Bool) -> Enumeration {
        Enumeration(
            serviceName: serviceName,
            description: description,
            typeName: typeName,
            values: values,
            isEncodable: isEncodable,
            isDecodable: isDecodable,
            collectionFormat: collectionFormat
        )
    }

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
        let hasRawValueSupport = isEncodable || isDecodable

        let valueNames =
            values
            .sorted(by: { $0 < $1 })
            .map { hasRawValueSupport ? $0.camelized : $0 }
            .map { Self.toCasename($0, hasRawValueSupport) }

        var cases = valueNames.map { "case \($0)" }

        var unknownName = "unknown"
        if valueNames.contains(unknownName) {
            unknownName = "unknownCase"
        }

        if hasRawValueSupport {
            cases += ["case \(unknownName)(String)"]
        }

        var model = """
            \(accessControl.rawValue) enum \(self.typeName)\(protocolConformanceSuffix) {
            \(cases.joined(separator: "\n").indentLines(1))
            """
        if hasRawValueSupport {
            let decodeCases =
                values
                .sorted()
                .map { "case \"\($0)\": self = .\(Self.toCasename($0, hasRawValueSupport))" }
                .joined(separator: "\n").indentLines(1)

            if isDecodable {
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
            }

            if isEncodable {
                let encodeCases = values.sorted().map {
                    """
                    case .\(Self.toCasename($0, hasRawValueSupport)):
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
            }

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
                case .\(Self.toCasename($0, hasRawValueSupport)):
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

    private var protocolConformanceSuffix: String {
        switch (isEncodable, isDecodable) {
        case (true, true):
            return ": Codable, Equatable, Sendable"
        case (true, false):
            return ": Encodable, Equatable, Sendable"
        case (false, true):
            return ": Decodable, Equatable, Sendable"
        case (false, false):
            return ": Sendable"
        }
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
