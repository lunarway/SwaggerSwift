import Foundation
import SwaggerSwiftML

enum IntegerResolver {
    static func resolve(serviceName: String, format: DataFormat?, defaultValue: Int?) -> TypeType {
        if let format = format {
            switch format {
            case .long:
                if let defaultValue = defaultValue {
                    return .double(defaultValue: Double(defaultValue))
                } else {
                    return .double(defaultValue: nil)
                }
            case .float:
                if let defaultValue = defaultValue {
                    return .float(defaultValue: Float(defaultValue))
                } else {
                    return .float(defaultValue: nil)
                }
            case .int32:
                return .int(defaultValue: defaultValue)
            case .double:
                if let defaultValue = defaultValue {
                    return .double(defaultValue: Double(defaultValue))
                } else {
                    return .double(defaultValue: nil)
                }
            case .date, .dateTime, .password, .email, .string, .byte, .binary, .boolean:
                log(
                    "⚠️: [\(serviceName)] SwaggerSwift does not support '\(format)' for integer type",
                    error: true
                )
                return .int(defaultValue: nil)
            case .unsupported(let unsupported):
                switch unsupported {
                case "int":
                    return .int(defaultValue: defaultValue)
                case "int64":
                    if let defaultValue = defaultValue {
                        return .int64(defaultValue: Int64(defaultValue))
                    } else {
                        return .int64(defaultValue: nil)
                    }
                case "decimal":
                    if let defaultValue = defaultValue {
                        return .double(defaultValue: Double(defaultValue))
                    } else {
                        return .double(defaultValue: nil)
                    }
                default:
                    log(
                        "⚠️ : SwaggerSwift does not support '\(unsupported)' for integer type. Use ",
                        error: true
                    )
                    return .int(defaultValue: defaultValue)
                }
            }
        }

        return .int(defaultValue: defaultValue)
    }
}
