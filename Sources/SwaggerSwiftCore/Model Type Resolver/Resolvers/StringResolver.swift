import Foundation
import SwaggerSwiftML

enum StringResolver {
    static func resolve(
        format: DataFormat?,
        enumValues: [String]?,
        typeNamePrefix: String,
        defaultValue: String?,
        serviceName: String
    ) -> TypeType {
        if enumValues != nil {
            let enumTypename = typeNamePrefix.modelNamed
            return .enumeration(typeName: enumTypename)
        }

        if let format = format {
            switch format {
            case .string:
                return .string(defaultValue: defaultValue)
            case .date:
                return .object(typeName: "Date")
            case .dateTime:
                return .object(typeName: "Date")
            case .password:
                return .string(defaultValue: defaultValue)
            case .email:
                return .string(defaultValue: defaultValue)
            case .binary:
                return .object(typeName: "Data")
            case .long, .float, .double, .byte, .boolean, .int32:
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
                    log(
                        "⚠️: \(serviceName): SwaggerSwift does not support '\(unsupported)' for strings",
                        error: true
                    )
                    return .typeAlias(typeName: typeNamePrefix, type: .string(defaultValue: defaultValue))
                }
            }
        } else {
            return .string(defaultValue: defaultValue)
        }
    }
}
