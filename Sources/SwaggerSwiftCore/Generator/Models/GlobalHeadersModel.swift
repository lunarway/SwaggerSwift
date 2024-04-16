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

        model += "public protocol \(typeName) {\n"

        model += properties.indentLines(1)

        model += "\n}"

        model += "\n"

        return model
    }

    public func writeExtensions(inCommonPackageNamed: String?) -> String {
        var model = "import Foundation\n"

        if let inCommonPackageNamed = inCommonPackageNamed {
            model += "import \(inCommonPackageNamed)\n"
        }

        model += "\n"

        model += "internal extension \(typeName) {\n"

        model += addToRequestFunction().indentLines(1)

        model += "\n\n"

        model += asDictionaryFunction().indentLines(1)

        model += "\n}\n"

        return model
    }

    private func addToRequestFunction() -> String {
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
    request.setValue(\($0.swiftyName), forHTTPHeaderField: \"\($0.fullHeaderName)\")
}
""" }
            .joined(separator: "\n\n")
            .indentLines(1)

        function += "\n"

        function += "}"

        return function
    }

    private func asDictionaryFunction() -> String {
        let fields = headerFields.map {
            APIRequestHeaderField(
                headerName: $0,
                isRequired: false
            )
        }

        var function = ""

        function += "var asDictionary: [String: String] {\n"
        function += "var headers = [String: String]()\n\n".indentLines(1)

        function += fields
            .sorted(by: { $0.swiftyName < $1.swiftyName })
            .map { """
if let \($0.swiftyName) = \($0.swiftyName) {
    headers[\"\($0.fullHeaderName)\"] = \($0.swiftyName)
}
""" }
            .joined(separator: "\n\n")
            .indentLines(1)

        function += "\n\nreturn headers".indentLines(1)

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
