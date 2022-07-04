import Foundation
import SwaggerSwiftML

/// Represents some kind of network model. This could be a response type or a request type.
struct GlobalHeadersModel {
    let typeName = "GlobalHeaders"
    let headerFields: [String]

    func modelDefinition(serviceName: String?, accessControl: APIAccessControl, swaggerFile: SwaggerFile) -> String {
        let fields = headerFields.map {
            APIRequestHeaderField(
                headerName: $0,
                isRequired: false
            )
        }

        let properties = fields
            .sorted(by: { $0.swiftyName < $1.swiftyName })
            .map { "var \($0.swiftyName): String\($0.isRequired ? "" : "?") { get }" }
            .joined(separator: "\n")

        var model = ""

        model += "\(accessControl.rawValue) protocol \(typeName) {\n"

        model += properties.indentLines(1)

        model += "\n}"

        model += "\n\n"

        model += "internal extension \(typeName) {\n"

        model += addToRequestFunction(accessControl: accessControl.rawValue).indentLines(1)

        model += "\n}\n"

        return model
    }

    func addToRequestFunction(accessControl: String) -> String {
        let fields = headerFields.map {
            APIRequestHeaderField(
                headerName: $0,
                isRequired: false
            )
        }

        var function = ""

        function += "func add(to request: inout URLRequest) {\n"

        function += fields
            .sorted(by: { $0.swiftyName < $1.swiftyName })
            .map { """
if let \($0.swiftyName) = \($0.swiftyName) {
    request.addValue(\($0.swiftyName), forHTTPHeaderField: \"\($0.fullHeaderName)\")
}
""" }
            .joined(separator: "\n\n")
            .indentLines(1)

        function += "\n"

        function += "}"

        return function
    }
}

extension GlobalHeadersModel {
    func toSwift(swaggerFile: SwaggerFile, accessControl: APIAccessControl) -> String {
        var model = ""
        model.appendLine("import Foundation")
        model.appendLine()

        model += modelDefinition(serviceName: nil, accessControl: accessControl, swaggerFile: swaggerFile)

        return model
    }
}
