import Foundation
import SwaggerSwiftML

/// Represents some kind of network model. This could be a response type or a request type.
struct ArrayModel {
    let description: String?
    let typeName: String
    let containsType: String
}

extension ArrayModel {
    func toSwift(serviceName: String?, embedded: Bool, packagesToImport: [String]) -> String {
        let typeString = "public typealias \(typeName) = [\(containsType)]"

        if !embedded {
            var model = ""
            model.appendLine("import Foundation")
            packagesToImport.forEach { model.appendLine("import \($0)") }
            model.appendLine()

            if let serviceName = serviceName {
                model.appendLine("extension \(serviceName) {")
            }

            model += typeString.indentLines(1)

            if let _ = serviceName {
                model.appendLine()
                model.appendLine("}")
            }

            return model
        } else {
            return typeString
        }
    }
}


struct TypeAliasModel {
    let typeName: String
    let type: String
}

extension TypeAliasModel {
    func toSwift(serviceName: String?, embedded: Bool, packagesToImport: [String]) -> String {
        let typeString = "public typealias \(typeName) = \(type)"

        if !embedded {
            var model = ""
            model.appendLine("import Foundation")
            packagesToImport.forEach { model.appendLine("import \($0)") }
            model.appendLine()

            if let serviceName = serviceName {
                model.appendLine("extension \(serviceName) {")
            }

            model += typeString.indentLines(1)

            if let _ = serviceName {
                model.appendLine()
                model.appendLine("}")
            }

            return model
        } else {
            return typeString
        }
    }
}
