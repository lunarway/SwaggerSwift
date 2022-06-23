import Foundation
import SwaggerSwiftML

/// Describes the types that can be returned from a function
indirect enum TypeType {
    case string
    case int
    case double
    case float
    case boolean(defaultValue: Bool?)
    case int64
    case array(typeName: TypeType)
    case object(typeName: String)
    case enumeration(typeName: String)
    case date
    case void
    case typeAlias(typeName: String, type: TypeType)

    func toString(required: Bool) -> String {
        return { obj -> String in
            switch obj {
            case .string:
                return "String"
            case .int:
                return "Int"
            case .double:
                return "Double"
            case .array(let typeName):
                return "[\(typeName.toString(required: true))]"
            case .object(let typeName):
                return typeName
            case .void:
                return "Void"
            case .boolean:
                return "Bool"
            case .float:
                return "Float"
            case .int64:
                return "Int64"
            case .date:
                return "Date"
            case .enumeration(let typeName):
                return typeName
            case .typeAlias(let typeName, _):
                return typeName
            }
        }(self) + (required ? "" : "?")
    }
}
