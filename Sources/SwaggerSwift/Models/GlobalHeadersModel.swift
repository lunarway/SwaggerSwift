import Foundation
import SwaggerSwiftML

/// Represents some kind of network model. This could be a response type or a request type.
struct GlobalHeadersModel {
    let typeName = "GlobalHeaders"
    let headerFields: [String]

    func modelDefinition(serviceName: String?, swaggerFile: SwaggerFile) -> String {
        let fields = headerFields.map {
            ModelField(description: nil,
                       type: .string,
                       name: makeHeaderFieldName(headerName: $0),
                       required: true)
        }

        let initParameterStrings: [String] = fields.map { field in
            let defaultArg: String
            if let defaultValue = field.defaultValue {
                defaultArg = " = " + defaultValue
            } else {
                defaultArg = ""
            }

            let fieldType = "\(field.type.toString(required: field.required || field.defaultValue != nil))"

            if field.needsArgumentLabel {
                return "\(field.argumentLabel) \(field.safeParameterName): \(fieldType)\(defaultArg)"
            } else {
                return "\(field.safeParameterName): \(fieldType)\(defaultArg)"
            }
        }

        let initMethod = """
public init(\(initParameterStrings.joined(separator: ", "))) {
    \(fields.map { "self.\($0.safePropertyName) = \($0.safeParameterName)" }.joined(separator: "\n    "))
}
"""

        let properties = fields.sorted(by: { $0.safePropertyName < $1.safePropertyName }).flatMap { $0.toSwift.split(separator: "\n") }

        var model = ""

        model += "public struct \(typeName) {\n"

        model += properties.map { $0 }.joined(separator: "\n").indentLines(1)

        model += "\n\n"

        model += initMethod.indentLines(1)

        model += "\n\n"

        model += addToRequestFunction().indentLines(1)

        model += "\n}"

        return model
    }

    func addToRequestFunction() -> String {
        var function = ""

        function += "func add(to request: inout URLRequest) {\n"

        function += headerFields.map { "request.addValue(\(makeHeaderFieldName(headerName: $0)), forHTTPHeaderField: \"\($0)\")" }.joined(separator: "\n").indentLines(1)
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
