/// Represents a Swift enum
struct Enumeration {
    let serviceName: String
    let description: String?
    let typeName: String
    let values: [String]
    let isCodable: Bool

    func modelDefinition(swaggerFile: SwaggerFile, embeddedFile: Bool) -> String {
        var cases = values
            .sorted(by: { $0 < $1 })
            .map { isCodable ? "case \($0.camelized)" :  "case \($0)"}

        var unknownName = "unknown"
        if values.contains(unknownName) {
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
            let decodeCases = values.sorted().map {
                """
case "\($0)":
    self = .\($0.camelized)
"""
            }.joined(separator: "\n").indentLines(1)

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
case .\($0.camelized):
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
case .\($0.camelized):
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
    func toSwift(swaggerFile: SwaggerFile, embedded: Bool) -> String {
        if embedded {
            return modelDefinition(swaggerFile: swaggerFile, embeddedFile: true)
        }

        var fileSections = ""
        fileSections += "extension \(serviceName) {\n"

        let modelDef = modelDefinition(swaggerFile: swaggerFile, embeddedFile: false)
        if let description = description, description.count > 0 {
            let comment = "// \(description)"
            fileSections += "\(comment)\n\(modelDef)".indentLines(1) + "\n"
        } else {
            fileSections += modelDef.indentLines(1) + "\n"
        }

        fileSections += "}"

        return fileSections
    }
}

extension String {
    func indentLines(_ count: Int) -> String {
        self.split(separator: "\n", omittingEmptySubsequences: false)
            .map { String(repeating: defaultSpacing, count: count) + $0 }
            .joined(separator: "\n")
    }
}
