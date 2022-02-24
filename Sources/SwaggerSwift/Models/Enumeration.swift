import Foundation
import SwaggerSwiftML

/// Represents a Swift enum
struct Enumeration {
    let serviceName: String?
    let description: String?
    let typeName: String
    let values: [String]
    let isCodable: Bool

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

    func modelDefinition(swaggerFile: SwaggerFile, embeddedFile: Bool) -> String {
        let valueNames = values
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
public enum \(self.typeName)\(isCodable ? ": Codable, Equatable" : "") {
\(cases.joined(separator: "\n").indentLines(1))
"""
        if isCodable {
            let decodeCases = values
                .sorted()
                .map { "case \"\($0)\": self = .\(Self.toCasename($0, isCodable))" }
                .joined(separator: "\n").indentLines(1)

            model += """


public init(from decoder: Decoder) throws {
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

public func encode(to encoder: Encoder) throws {
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

public init(rawValue: String) {
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

public var rawValue: String {
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

extension Enumeration: Swiftable {
    func toSwift(serviceName: String?, swaggerFile: SwaggerFile, embedded: Bool, packagesToImport: [String]) -> String {
        if embedded {
            return modelDefinition(swaggerFile: swaggerFile, embeddedFile: true)
        }

        var fileSections = ""
        fileSections += packagesToImport.map{"import \($0)"}.joined(separator: "\n")
        if let serviceName = serviceName {
            fileSections += "\n\nextension \(serviceName) {\n"
        }

        let modelDef = modelDefinition(swaggerFile: swaggerFile, embeddedFile: false)
        if let description = description, description.count > 0 {
            let comment = "// \(description)"
            fileSections += "\(comment)\n\(modelDef)".indentLines(1) + "\n"
        } else {
            fileSections += modelDef.indentLines(1) + "\n"
        }

        if serviceName != nil {
            fileSections += "}"
        }

        return fileSections
    }
}

extension String {
    func indentLines(_ count: Int) -> String {
        self.split(separator: "\n", omittingEmptySubsequences: false)
            .map {
                if $0.trimmingCharacters(in: .whitespaces).count > 0 {
                    return String(repeating: defaultSpacing, count: count) + $0
                } else {
                    return ""
                }
            }
            .joined(separator: "\n")
    }
}

extension String {
    var isNumber: Bool {
        return !isEmpty && rangeOfCharacter(from: CharacterSet.decimalDigits.inverted) == nil
    }
}
