import Foundation
import SwaggerSwiftML

/// Describes the types that can be returned from a function
indirect enum TypeType {
    case string(defaultValue: String?)
    case int(defaultValue: Int?)
    case double(defaultValue: Double?)
    case float(defaultValue: Float?)
    case boolean(defaultValue: Bool?)
    case int64(defaultValue: Int64?)
    case array(type: TypeType)
    case object(typeName: String)
    case enumeration(typeName: String)
    case date
    case void
    // represents a type that has a declared type alias in the Swagger, e.g.
    // MyType:
    //   type: string
    // or:
    // MyOtherType:
    //   $ref: '#/definitions/SomeType'
    // These types can only be declared on the top level of definitions or responses in the Swagger as inline type alias' just resolves to the "type alias name" being the property name, e.g.
    // MyResponseType:
    //   properties:
    //     - coolString:
    //         type: string
    // in this case `coolString` will just be a property named `coolString` with type `String`
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
