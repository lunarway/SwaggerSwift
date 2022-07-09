import Foundation
import SwaggerSwiftML

enum NumberResolver {
    static func resolve(format: DataFormat?, defaultValue: Double?) -> TypeType {
        if let format = format {
            switch format {
            case .long:
                return .double(defaultValue: defaultValue)
            case .float:
                if let defaultValue = defaultValue {
                    return .float(defaultValue: Float(defaultValue))
                } else {
                    return .float(defaultValue: nil)
                }
            case .int32:
                if let defaultValue = defaultValue {
                    return .int(defaultValue: Int(defaultValue))
                } else {
                    return .int(defaultValue: nil)
                }
            case .double:
                return .double(defaultValue: defaultValue)
            case .date: fallthrough
            case .dateTime: fallthrough
            case .password: fallthrough
            case .email: fallthrough
            case .string: fallthrough
            case .byte: fallthrough
            case .binary: fallthrough
            case .boolean:
                log("⚠️: SwaggerSwift does not support '\(format)' for number", error: true)
                return .double(defaultValue: defaultValue)
            case .unsupported(let unsupported):
                switch unsupported {
                case "int", "integer":
                    if let defaultValue = defaultValue {
                        return .int(defaultValue: Int(defaultValue))
                    } else {
                        return .int(defaultValue: nil)
                    }
                case "int64":
                    if let defaultValue = defaultValue {
                        return .int64(defaultValue: Int64(defaultValue))
                    } else {
                        return .int64(defaultValue: nil)
                    }
                case "float64":
                    log("⚠️: `format: float64` format does not exist for type number in the Swagger spec. Please change it to specify `format: double` instead.", error: true)
                    return .double(defaultValue: defaultValue)
                case "decimal":
                    return .double(defaultValue: defaultValue)
                default:
                    log("⚠️: SwaggerSwift does not support '\(unsupported)' for number", error: true)
                    return .double(defaultValue: defaultValue)
                }
            }
        }

        return .double(defaultValue: defaultValue)
    }
}
