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
        let typeName =
            switch self {
            case .string:
                "String"
            case .int:
                "Int"
            case .double:
                "Double"
            case .array(let typeName):
                "[\(typeName.toString(required: true))]"
            case .object(let typeName):
                typeName
            case .void:
                "Void"
            case .boolean:
                "Bool"
            case .float:
                "Float"
            case .int64:
                "Int64"
            case .date:
                "Date"
            case .enumeration(let typeName):
                typeName
            case .typeAlias(let typeName, _):
                typeName
            }

        return typeName + (required ? "" : "?")
    }
}
