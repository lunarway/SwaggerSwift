import Foundation
import SwaggerSwiftML

/// Represents some kind of network model. This could be a response type or a request type.
struct Model {
    let serviceName: String
    let description: String?
    let typeName: String
    let fields: [ModelField]
    let inheritsFrom: [String]

    func resolveInherits(_ definitions: [Model]) -> Model {
        let inherits = inheritsFrom.map { inherit in definitions.first(where: { $0.typeName == inherit })! }
        let inheritedFields = inherits.flatMap { $0.fields }
        return Model(serviceName: serviceName,
                     description: description,
                     typeName: typeName,
                     fields: fields + inheritedFields,
                     inheritsFrom: [])
    }
}

extension Model: Swiftable {
    func toSwift() -> String {
        let hasDate = fields.contains(where: {
            if case TypeType.date = $0.type {
                return true
            } else {
                return false
            }
        })

        let defaultSpacing = "    "
        var dateParsing = ""
        if hasDate {
            dateParsing += """


\(defaultSpacing)enum CodingKeys: String, CodingKey {
\(defaultSpacing)\(defaultSpacing)\(fields.sorted(by: { $0.name < $1.name }).map { "case \($0.name)" }.joined(separator: "\n").replacingOccurrences(of: "\n", with: "\n\(defaultSpacing)\(defaultSpacing)"))
\(defaultSpacing)}

""".replacingOccurrences(of: "\n", with: "\n    ")

            dateParsing += """

\(defaultSpacing)\(defaultSpacing)init(from decoder: Decoder) throws {
\(defaultSpacing)\(defaultSpacing)\(defaultSpacing)let iso8601DateFormatter = ISO8601DateFormatter()
\(defaultSpacing)\(defaultSpacing)\(defaultSpacing)let container = try decoder.container(keyedBy: CodingKeys.self)
\(defaultSpacing)\(fields.sorted(by: { $0.name < $1.name }).map { $0.decoderLine(typeName: self.typeName, indentationLevel: 2) }.joined(separator: "\n").replacingOccurrences(of: "\n", with: "\n\(defaultSpacing)"))
\(defaultSpacing)\(defaultSpacing)}

"""

            dateParsing += """

\(defaultSpacing)\(defaultSpacing)func encode(to encoder: Encoder) throws {
\(defaultSpacing)\(defaultSpacing)\(defaultSpacing)let iso8601DateFormatter = ISO8601DateFormatter()
\(defaultSpacing)\(defaultSpacing)\(defaultSpacing)var container = encoder.container(keyedBy: CodingKeys.self)
\(defaultSpacing)\(fields.sorted(by: { $0.name < $1.name }).map { $0.encoderLine(typeName: self.typeName, indentationLevel: 2) }.joined(separator: "\n").replacingOccurrences(of: "\n", with: "\n\(defaultSpacing)"))
\(defaultSpacing)\(defaultSpacing)}
"""
        }

        let comment = description != nil && description!.count > 0 ? "\n\(defaultSpacing)// \(description ?? "")" : ""

        return """
import Foundation

extension \(serviceName) {\(comment)
    struct \(typeName): \((inheritsFrom + ["Codable"]).joined(separator: ", ")) {
\(fields.sorted(by: { $0.name < $1.name }).map { $0.toSwift.split(separator: "\n") }.flatMap { Array($0) }.map { "\(defaultSpacing)\(defaultSpacing)\($0)" }.joined(separator: "\n"))\(dateParsing)
    }
}
"""
    }
}

extension ModelField {
    func decoderLine(typeName: String, indentationLevel: Int) -> String {
        if case TypeType.date = self.type {
            if required {
                return decoderRequiredDate(fieldName: self.name, typeName: self.type.toString(), indentationLevel: indentationLevel)
            } else {
                return decoderOptionalDate(fieldName: self.name, indentationLevel: indentationLevel)
            }
        } else {
            let indentation = String(repeating: defaultSpacing, count: indentationLevel)

            if required {
                return "\(indentation)self.\(self.name) = try container.decode(\(self.type.toString()).self, forKey: .\(self.name))"
            } else {
                return """
                \(indentation)self.\(self.name) = try container.decodeIfPresent(\(self.type.toString()).self, forKey: .\(self.name))
                """
            }
        }
    }

    func encoderLine(typeName: String, indentationLevel: Int) -> String {
        if case TypeType.date = self.type {
            if required {
                return encoderRequiredDate(fieldName: self.name, indentationLevel: indentationLevel)
            } else {
                return encoderOptionalDate(fieldName: self.name, indentationLevel: indentationLevel)
            }
        } else {
            let indentation = String(repeating: defaultSpacing, count: indentationLevel)

            if required {
                return """
                \(indentation)try container.encode(\(self.name), forKey: .\(self.name))
                """
            } else {
                return """
                \(indentation)try container.encodeIfPresent(\(self.name), forKey: .\(self.name))
                """
            }
        }
    }
}

func decoderOptionalDate(fieldName: String, indentationLevel: Int) -> String {
    let indentation = String(repeating: defaultSpacing, count: indentationLevel)
    return """
    \(indentation)if let \(fieldName)String = try container.decodeIfPresent(String.self, forKey: .\(fieldName)) {
    \(indentation)\(defaultSpacing)self.\(fieldName) = iso8601DateFormatter.date(from: \(fieldName)String)
    \(indentation)} else {
    \(indentation)\(defaultSpacing)self.\(fieldName) = nil
    \(indentation)}
    """
}

func decoderRequiredDate(fieldName: String, typeName: String, indentationLevel: Int) -> String {
    let indentation = String(repeating: defaultSpacing, count: indentationLevel)
    return """
\(indentation)let \(fieldName)String = try container.decode(String.self, forKey: .\(fieldName))
\(indentation)if let \(fieldName) = iso8601DateFormatter.date(from: \(fieldName)String) {
\(indentation)    self.\(fieldName) = \(fieldName)
\(indentation)} else {
\(indentation)    throw JSONParsingError.invalidDate(\(fieldName)String)
\(indentation)}
"""
}

func encoderOptionalDate(fieldName: String, indentationLevel: Int) -> String {
    let indentation = String(repeating: defaultSpacing, count: indentationLevel)
    return """
    \(indentation)if let \(fieldName) = \(fieldName) {
    \(indentation)\(defaultSpacing)let \(fieldName)String = iso8601DateFormatter.string(from: \(fieldName))
    \(indentation)\(defaultSpacing)try container.encode(\(fieldName)String, forKey: .\(fieldName))
    \(indentation)}
    """
}

func encoderRequiredDate(fieldName: String, indentationLevel: Int) -> String {
    let indentation = String(repeating: defaultSpacing, count: indentationLevel)
    return """
    \(indentation)let \(fieldName)String = iso8601DateFormatter.string(from: \(fieldName))
    \(indentation)try container.encode(\(fieldName)String, forKey: .\(fieldName))
    """
}
