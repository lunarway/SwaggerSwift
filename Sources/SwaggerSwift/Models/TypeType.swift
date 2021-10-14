import Foundation
import SwaggerSwiftML

protocol test {
    func abc(handler: @escaping (() -> Void))
}

/// Describes the types that can be returned from a function
indirect enum TypeType {
    case string
    case int
    case double
    case float
    case boolean(defaultValue: Bool?)
    case int64
    case array(typeName: TypeType)
    case object(typeName: String, defaultValue: String? = nil)
    case date
    case void

    func toString(required: Bool, withDefaultValue: Bool = true) -> String {
        return { obj -> String in
            switch obj {
            case .string:
                return "String"
            case .int:
                return "Int"
            case .double:
                return "Double"
            case .array(typeName: let typeName):
                return "[\(typeName.toString(required: true))]"
            case .object(typeName: let typeName, defaultValue: let defaultValue):
                return typeName + (defaultValue != nil && withDefaultValue ? " = \(defaultValue!)" : "")
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
            }
        }(self) + (required ? "" : "?")
    }
}
