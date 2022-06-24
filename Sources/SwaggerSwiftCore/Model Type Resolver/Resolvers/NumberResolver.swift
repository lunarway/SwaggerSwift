import Foundation
import SwaggerSwiftML

enum NumberResolver {
    static func resolve(format: DataFormat?) -> TypeType {
        if let format = format {
            switch format {
            case .long:
                return .double
            case .float:
                return .float
            case .int32:
                return .int
            case .double:
                return .double
            case .date: fallthrough
            case .dateTime: fallthrough
            case .password: fallthrough
            case .email: fallthrough
            case .string: fallthrough
            case .byte: fallthrough
            case .binary: fallthrough
            case .boolean:
                log("⚠️: SwaggerSwift does not support '\(format)' for number", error: true)
                return .double
            case .unsupported(let unsupported):
                switch unsupported {
                case "int", "integer":
                    return .int
                case "int64":
                    return .int64
                case "float64":
                    log("⚠️: `format: float64` format does not exist for type number in the Swagger spec. Please change it to specify `format: double` instead.", error: true)
                    return .double
                case "decimal":
                    return .double
                default:
                    log("⚠️: SwaggerSwift does not support '\(unsupported)' for number", error: true)
                    return .double
                }
            }
        }

        return .double
    }
}
