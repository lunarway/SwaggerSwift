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
    serviceName: String?, embedded: Bool, accessControl: APIAccessControl,
    packagesToImport: [String]
  ) -> String {
    let typeString = "\(accessControl.rawValue) typealias \(typeName) = \(type)"

    if !embedded {
      var model = ""
      model.appendLine("import Foundation")
      packagesToImport.forEach { model.appendLine("import \($0)") }
      model.appendLine()

      if let serviceName = serviceName {
        model.appendLine("extension \(serviceName) {")
      }

      model += typeString.indentLines(1)

      if serviceName != nil {
        model.appendLine()
        model.appendLine("}")
      }

      return model
    } else {
      return typeString
    }
  }
}
