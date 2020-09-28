struct SwiftCodableStruct: SwiftType {
    var description: String

    let documentation: String?
    let typeName: String
    let properties: [SwiftProperty]
    let conformance: [String]
}

//func decoderOptionalDate(fieldName: String, indentationLevel: Int) -> String {
//    let indentation = String(repeating: defaultSpacing, count: indentationLevel)
//    return """
//    \(indentation)if let \(fieldName)String = try container.decodeIfPresent(String.self, forKey: .\(fieldName)) {
//    \(indentation)\(defaultSpacing)self.\(fieldName) = iso8601DateFormatter.date(from: \(fieldName)String)
//    \(indentation)} else {
//    \(indentation)\(defaultSpacing)self.\(fieldName) = nil
//    \(indentation)}
//    """
//}
//
//func decoderRequiredDate(fieldName: String, typeName: String, indentationLevel: Int) -> String {
//    let indentation = String(repeating: defaultSpacing, count: indentationLevel)
//    return """
//    \(indentation)let \(fieldName)String = iso8601DateFormatter.string(from: \(fieldName))
//    \(indentation)try container.encode(\(fieldName)String, forKey: .\(fieldName))
//    """
//}
//
//func encoderOptionalDate(fieldName: String, indentationLevel: Int) -> String {
//    let indentation = String(repeating: defaultSpacing, count: indentationLevel)
//    return """
//    \(indentation)if let \(fieldName) = \(fieldName) {
//    \(indentation)\(defaultSpacing)let \(fieldName)String = iso8601DateFormatter.string(from: \(fieldName))
//    \(indentation)\(defaultSpacing)try container.encode(\(fieldName)String, forKey: .\(fieldName))
//    \(indentation)}
//    """
//}
//
//func encoderRequiredDate(fieldName: String, indentationLevel: Int) -> String {
//    let indentation = String(repeating: defaultSpacing, count: indentationLevel)
//    return """
//    \(indentation)let \(fieldName)String = iso8601DateFormatter.string(from: \(fieldName))
//    \(indentation)try container.encode(\(fieldName)String, forKey: .\(fieldName))
//    """
//}
//
//extension SwiftProperty {
//    func decoderLine(typeName: String, indentationLevel: Int) -> String {
//        if self.type == "Date" {
//            if required {
//                return decoderRequiredDate(fieldName: self.name, typeName: typeName, indentationLevel: indentationLevel)
//            } else {
//                return decoderOptionalDate(fieldName: self.name, indentationLevel: indentationLevel)
//            }
//        } else {
//            let indentation = String(repeating: defaultSpacing, count: indentationLevel)
//
//            if required {
//                return """
//                \(indentation)self.\(self.name) = try container.decode(\(self.type).self, forKey: .\(self.name))
//                """
//            } else {
//                return """
//                \(indentation)self.\(self.name) = try container.decodeIfPresent(\(self.type).self, forKey: .\(self.name))
//                """
//            }
//        }
//    }
//
//    func encoderLine(typeName: String, indentationLevel: Int) -> String {
//        if self.type == "Date" {
//            if required {
//                return encoderRequiredDate(fieldName: self.name, indentationLevel: indentationLevel)
//            } else {
//                return encoderOptionalDate(fieldName: self.name, indentationLevel: indentationLevel)
//            }
//        } else {
//            let indentation = String(repeating: defaultSpacing, count: indentationLevel)
//
//            if required {
//                return """
//                \(indentation)try container.encode(\(self.name), forKey: .\(self.name))
//                """
//            } else {
//                return """
//                \(indentation)try container.encodeIfPresent(\(self.name), forKey: .\(self.name))
//                """
//            }
//        }
//    }
//}

//extension SwiftCodableStruct: CustomStringConvertible {
//    var description: String {
//        assert(typeName.count > 0, "No type name found on struct")
//        var result = ""
//
//        let hasDate = properties.contains(where: { $0.type == "Date" })
//
//        if hasDate {
//            result += "import Foundation\n\n"
//        }
//
//        if let documentation = documentation {
//            result += "/// \(documentation)\n"
//        }
//
//        let conformances = conformance.joined(separator: ", ")
//
//        result += """
//        struct \(self.typeName): Codable\(conformances.count > 0 ? ", \(conformances)" : "") {
//        \(properties.map { $0.description }.joined(separator: "\n"))\n
//        """
//
//        if hasDate {
//            result += """
//            \n\(defaultSpacing)enum CodingKeys: String, CodingKey {
//            \(properties.map { "\(defaultSpacing)\(defaultSpacing)case \($0.name)" }.joined(separator: "\n"))
//            \(defaultSpacing)}\n
//            """
//
//            result += """
//            \n\(defaultSpacing)init(from decoder: Decoder) throws {
//            let iso8601DateFormatter = ISO8601DateFormatter()
//            \(defaultSpacing)\(defaultSpacing)let container = try decoder.container(keyedBy: CodingKeys.self)
//            \(properties.map { $0.decoderLine(typeName: self.typeName, indentationLevel: 2) }.joined(separator: "\n"))
//            \(defaultSpacing)}\n
//            """
//
//            result += """
//            \n\(defaultSpacing)func encode(to encoder: Encoder) throws {
//            let iso8601DateFormatter = ISO8601DateFormatter()
//            \(defaultSpacing)\(defaultSpacing)var container = encoder.container(keyedBy: CodingKeys.self)
//            \(properties.map { $0.encoderLine(typeName: self.typeName, indentationLevel: 2) }.joined(separator: "\n"))
//            \(defaultSpacing)}\n
//            """
//        }
//
//        result += """
//        }
//        """
//
//        result += """
//        \n\nextension \(typeName): Equatable { }
//        """
//
//        return result
//    }
//}
