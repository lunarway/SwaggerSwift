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
    ) throws -> String {
        var context: [String: Any] = [
            "typeName": typeName,
            "containsType": containsType,
            "accessControl": accessControl.rawValue,
            "embedded": embedded,
            "packagesToImport": packagesToImport,
        ]
        if let serviceName { context["serviceName"] = serviceName }

        return try templateRenderer.render(template: "ArrayModel.stencil", context: context)
    }
}
