import Foundation
import SwaggerSwiftML

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
//
struct TypeAliasModel {
    let typeName: String
    let type: String
}

extension TypeAliasModel {
    func toSwift(
        serviceName: String?,
        embedded: Bool,
        accessControl: APIAccessControl,
        packagesToImport: [String],
        templateRenderer: TemplateRenderer
    ) throws -> String {
        let context: [String: Any] = [
            "typeName": typeName,
            "type": type,
            "accessControl": accessControl.rawValue,
            "embedded": embedded,
            "serviceName": serviceName as Any,
            "packagesToImport": packagesToImport,
        ]

        return try templateRenderer.render(template: "Typealias.stencil", context: context)
    }
}
