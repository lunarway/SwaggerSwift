import Foundation
import SwaggerSwiftML

struct ArrayModel {
    let description: String?
    let typeName: String
    let containsType: String
}

extension ArrayModel {
    func toSwift(
        serviceName: String?,
        embedded: Bool,
        accessControl: APIAccessControl,
        packagesToImport: [String],
        templateRenderer: TemplateRenderer
    ) -> String {
        let context: [String: Any] = [
            "typeName": typeName,
            "containsType": containsType,
            "accessControl": accessControl.rawValue,
            "embedded": embedded,
            "serviceName": serviceName as Any,
            "packagesToImport": packagesToImport,
        ]

        return try! templateRenderer.render(template: "ArrayModel.stencil", context: context)
    }
}
