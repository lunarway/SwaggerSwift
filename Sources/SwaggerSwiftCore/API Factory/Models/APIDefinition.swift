import Foundation
import SwaggerSwiftML

/// Represent the overall service definition with all the network request methods and the primary initialiser
struct APIDefinition {
    let serviceName: String
    let description: String?
    let fields: [APIDefinitionField]
    let functions: [APIRequest]

    func toSwift(
        swaggerFile: SwaggerFile,
        accessControl: String,
        packagesToImport: [String],
        templateRenderer: TemplateRenderer
    ) throws -> String {
        let initMethod = """
            /// Create an instance of \(serviceName)
            /// - Parameters:
            \(fields.map { $0.documentationString }.joined(separator: "\n"))
            \(accessControl) init(\(fields.map { $0.initProperty }.joined(separator: ", "))) {
            \(fields.map { $0.initAssignment }.joined(separator: "\n").indentLines(1))
            }
            """

        let requestHelpers = """
            private func _performRequest(request: URLRequest, requestData: Data?) async throws -> (Data, URLResponse, HTTPURLResponse) {
                let request = interceptor?.networkWillPerformRequest(request) ?? request

                let data: Data
                let response: URLResponse
                if let requestData {
                    (data, response) = try await urlSession().upload(for: request, from: requestData)
                } else {
                    (data, response) = try await urlSession().data(for: request)
                }

                if let interceptor {
                    try await interceptor.networkDidPerformRequest(
                        urlRequest: request,
                        urlResponse: response,
                        data: data,
                        error: nil
                    )
                }

                guard let httpResponse = response as? HTTPURLResponse else {
                    fatalError("The response must be a URL response")
                }

                return (data, response, httpResponse)
            }

            private func _makeJSONDecoder() -> JSONDecoder {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .custom(dateDecodingStrategy)
                return decoder
            }

            private func _unknownStatusError(statusCode: Int, data: Data) -> NSError {
                let result = String(data: data, encoding: .utf8) ?? ""
                return NSError(
                    domain: "\(serviceName)",
                    code: statusCode,
                    userInfo: [NSLocalizedDescriptionKey: result]
                )
            }
            """

        let properties =
            fields
            .map {
                "private let \($0.name): \($0.typeIsBlock ? "@Sendable " : "")\($0.typeName)\($0.isRequired ? "" : "?")"
            }
            .joined(separator: "\n")

        let apiFunctions = self.functions
            .sorted(by: { $0.functionName < $1.functionName })
            .map {
                $0.toSwift(
                    serviceName: serviceName,
                    swaggerFile: swaggerFile,
                    embedded: false,
                    accessControl: accessControl,
                    packagesToImport: packagesToImport
                )
            }.joined(separator: "\n")
            .trimmingCharacters(in: CharacterSet.newlines)

        var context: [String: Any] = [
            "serviceName": serviceName,
            "accessControl": accessControl,
            "packagesToImport": packagesToImport,
            "properties": properties,
            "initMethod": initMethod,
            "requestHelpers": requestHelpers,
            "apiFunctions": apiFunctions,
        ]
        if let description { context["description"] = description }

        return try templateRenderer.render(template: "APIDefinition.stencil", context: context)
    }
}
