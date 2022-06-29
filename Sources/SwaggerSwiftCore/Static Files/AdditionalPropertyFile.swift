let additionalPropertyUtil = """
import Foundation

<ACCESSCONTROL> enum AdditionalProperty: Codable {
    case string(String)
    case integer(Int)
    case double(Double)
    case dictionary([String: AdditionalProperty])
    case array([AdditionalProperty])
    case bool(Bool)
    case null

    <ACCESSCONTROL> init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let stringValue = try? container.decode(String.self) {
            self = .string(stringValue)
        } else if let intValue = try? container.decode(Int.self) {
            self = .integer(intValue)
        } else if let doubleValue = try? container.decode(Double.self) {
            self = .double(doubleValue)
        } else if let dictionaryValue = try? container.decode([String: AdditionalProperty].self) {
            self = .dictionary(dictionaryValue)
        } else if let arrayValue = try? container.decode([AdditionalProperty].self) {
            self = .array(arrayValue)
        } else if let boolValue = try? container.decode(Bool.self) {
            self = .bool(boolValue)
        } else if container.decodeNil() {
            self = .null
        } else {
            throw DecodingError.typeMismatch(
                AdditionalProperty.self,
                DecodingError.Context(codingPath: container.codingPath,
                                      debugDescription: "AdditionalProperty contained un-supported value type")
            )
        }
    }

    <ACCESSCONTROL> func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let stringValue):
            try container.encode(stringValue)
        case .integer(let value):
            try container.encode(value)
        case .double(let value):
            try container.encode(value)
        case .dictionary(let value):
            try container.encode(value)
        case .array(let value):
            try container.encode(value)
        case .bool(let value):
            try container.encode(value)
        case .null:
            try container.encodeNil()
        }
    }
}

"""
