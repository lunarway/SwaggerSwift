import Foundation
import SwaggerSwiftML

/// Represents some kind of network model. This could be a response type or a request type.
struct Model {
    let serviceName: String?
    let description: String?
    let typeName: String
    let fields: [ModelField]
    let inheritsFrom: [String]
    let isInternalOnly: Bool

    func resolveInherits(_ definitions: [Model]) -> Model {
        let inherits = inheritsFrom.compactMap { definitionName in
            definitions.first(where: { $0.typeName == definitionName })
        }

        let inheritedFields = inherits.flatMap { $0.fields }
        return Model(serviceName: serviceName,
                     description: description,
                     typeName: typeName,
                     fields: (fields + inheritedFields).sorted(by: { $0.name < $1.name }),
                     inheritsFrom: inheritsFrom,
                     isInternalOnly: isInternalOnly)
    }
}

extension Model: Swiftable {
    func toSwift(swaggerFile: SwaggerFile) -> String {
        let defaultSpacing = "    "

        let initMethod = """
public init(\(fields.map { "\($0.name): \($0.type.toString(required: $0.required))" }.joined(separator: ", "))) {
    \(fields.map { "self.\($0.name) = \($0.name)" }.joined(separator: "\n    "))
}
"""
        let readyFields = fields.sorted(by: { $0.name < $1.name }).flatMap { $0.toSwift.split(separator: "\n") }


        var indentLevel = 0
        let indentation = { String(repeating: defaultSpacing, count: indentLevel) }

        let comment: String?
        if let description = description {
            comment = description.split(separator: "\n").map {
                "// \($0)"
            }.joined(separator: "\n")
        } else {
            comment = nil
        }

        var model = "\(indentation())import Foundation\n\n"

        if isInternalOnly {
            model += "#if DEBUG\n"
        }

        if let serviceName = serviceName {
            model += "\(indentation())extension \(serviceName) {\n"
            indentLevel += 1
        }

        if let comment = comment {
            model += indentation() + comment.replacingOccurrences(of: "\n", with: "\(indentation())\n") + "\n"
        }

        model += "\(indentation())public struct \(typeName)\(inheritsFrom.count > 0 ? ": \(inheritsFrom.joined(separator: ", "))" : "") {\n"
        indentLevel += 1

        for field in readyFields {
            model += indentation() + field + "\n"
        }

        if readyFields.count > 0 {
            model += "\n"
        }

        model += indentation() + initMethod.replacingOccurrences(of: "\n", with: "\n\(indentation())") + "\n"

        indentLevel -= 1

        model += "\(indentation())}\n"
        indentLevel -= 1

        if let _ = serviceName {
            model += "\(indentation())}\n"
        }

        if isInternalOnly {
            model += "#endif\n"
        }

        return model
    }
}

extension ModelField {
    func decoderLine(typeName: String, indentationLevel: Int) -> String {
        if case TypeType.date = self.type {
            if required {
                return decoderRequiredDate(fieldName: self.name, typeName: self.type.toString(required: self.required), indentationLevel: indentationLevel)
            } else {
                return decoderOptionalDate(fieldName: self.name, indentationLevel: indentationLevel)
            }
        } else {
            let indentation = String(repeating: defaultSpacing, count: indentationLevel)

            if required {
                return "\(indentation)self.\(self.name) = try container.decode(\(self.type.toString(required: self.required)).self, forKey: .\(self.name))"
            } else {
                return """
                \(indentation)self.\(self.name) = try container.decodeIfPresent(\(self.type.toString(required: self.required)).self, forKey: .\(self.name))
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
