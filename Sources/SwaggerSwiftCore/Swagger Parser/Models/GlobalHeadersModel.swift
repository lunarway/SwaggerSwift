import Foundation
import SwaggerSwiftML

/// Represents some kind of network model. This could be a response type or a request type.
struct GlobalHeadersModel {
    let typeName = "GlobalHeaders"
    let headerFields: [String]

    func modelDefinition(serviceName: String?, swaggerFile: SwaggerFile) -> String {
        let fields = headerFields.map {
            APIRequestHeaderField(
                headerName: $0,
                isRequired: true
            )
        }

        let initMethod = """
public init(\(fields.asInitParameter())) {
\(fields.asInitAssignments().indentLines(1))
}
"""

        let properties = fields.asPropertyList()

        var model = ""

        model += "public struct \(typeName) {\n"

        model += properties.indentLines(1)

        model += "\n\n"

        model += initMethod.indentLines(1)

        model += "\n\n"

        model += addToRequestFunction().indentLines(1)

        model += "\n}"

        return model
    }

    func addToRequestFunction() -> String {
        let fields = headerFields.map {
            APIRequestHeaderField(
                headerName: $0,
                isRequired: true
            )
        }

        var function = ""

        function += "public func add(to request: inout URLRequest) {\n"

        function += fields
            .sorted(by: { $0.swiftyName < $1.swiftyName })
            .map { "request.addValue(\($0.swiftyName), forHTTPHeaderField: \"\($0.fullHeaderName)\")" }
            .joined(separator: "\n")
            .indentLines(1)

        function += "\n"

        function += "}"

        return function
    }
}

extension GlobalHeadersModel {
    func toSwift(swaggerFile: SwaggerFile) -> String {
        var model = ""
        model.appendLine("import Foundation")
        model.appendLine()

        model += modelDefinition(serviceName: nil, swaggerFile: swaggerFile)

        return model
    }
}
