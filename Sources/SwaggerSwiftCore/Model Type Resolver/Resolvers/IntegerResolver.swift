import Foundation
import SwaggerSwiftML

enum IntegerResolver {
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
                log("⚠️: SwaggerSwift does not support '\(format)' for integer type", error: true)
                return .int
            case .unsupported(let unsupported):
                switch unsupported {
                case "int":
                    return .int
                case "int64":
                    return .int64
                case "decimal":
                    return .double
                default:
                    log("⚠️ : SwaggerSwift does not support '\(unsupported)' for integer type. Use ", error: true)
                    return .int
                }
            }
        }

        return .int
    }
}
