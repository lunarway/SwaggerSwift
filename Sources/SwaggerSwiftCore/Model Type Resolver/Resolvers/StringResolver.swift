import Foundation
import SwaggerSwiftML

enum StringResolver {
    static func resolve(format: DataFormat?, enumValues: [String]?, typeNamePrefix: String) -> TypeType {
        if enumValues != nil {
            let enumTypename = typeNamePrefix.modelNamed
            return .enumeration(typeName: enumTypename)
        }

        if let format = format {
            switch format {
            case .string:
                return .string
            case .date:
                return .object(typeName: "Date")
            case .dateTime:
                return .object(typeName: "Date")
            case .password:
                return .string
            case .email:
                return .string
            case .binary:
                return .object(typeName: "Data")
            case .long: fallthrough
            case .float: fallthrough
            case .double: fallthrough
            case .byte: fallthrough
            case .boolean: fallthrough
            case .int32:
                log("⚠️: A string should not be defined to be a \(format)", error: true)
                return .object(typeName: "String")
            case .unsupported(let unsupported):
                switch unsupported {
                case "ISO8601":
                    return .date
                case "uuid":
                    return .object(typeName: "String")
                case "datetime":
                    return .object(typeName: "Date")
                case "uri":
                    return .object(typeName: "URL")
                default:
                    log("⚠️: SwaggerSwift does not support '\(unsupported)' for strings", error: true)
                    return .typeAlias(typeName: typeNamePrefix, type: .string)
                }
            }
        } else {
            return .string
        }
    }
}
