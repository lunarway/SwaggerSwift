import Foundation
import SwaggerSwiftML

/// Represent the overall service definition with all the network request methods and the primary initialiser
struct APIDefinition {
    let serviceName: String
    let description: String?
    let fields: [APIDefinitionField]
    let functions: [APIRequest]

    func toSwift(swaggerFile: SwaggerFile, accessControl: String, packagesToImport: [String])
        -> String
    {
        let importStatements = (["Foundation"] + packagesToImport).map { "import \($0)" }.joined(
            separator: "\n"
        )

        let initMethod = """
            /// Create an instance of \(serviceName)
            /// - Parameters:
            \(fields.map { $0.documentationString }.joined(separator: "\n"))
            \(accessControl) init(\(fields.map { $0.initProperty }.joined(separator: ", "))) {
            \(fields.map { $0.initAssignment }.joined(separator: "\n").indentLines(1))
            }
            """.indentLines(1)

        let requestHelpers = """
            private func _performRequest(request: URLRequest, requestData: Data?) async throws -> (Data, URLResponse, HTTPURLResponse) {
                let request = interceptor?.networkWillPerformRequest(request) ?? request

                let data: Data
                let response: URLResponse
                do {
                    if let requestData {
                        (data, response) = try await urlSession().upload(for: request, from: requestData)
                    } else {
                        (data, response) = try await urlSession().data(for: request)
                    }
                } catch {
                    throw error
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
            """.indentLines(1)

        var serviceDefinition = "\(importStatements)\n\n"

        if let description = description {
            serviceDefinition.append("// \(description)\n")
        }

        let properties =
            fields
            .map {
                "private let \($0.name): \($0.typeIsBlock ? "@Sendable " : "")\($0.typeName)\($0.isRequired ? "" : "?")"
            }
            .joined(separator: "\n")
            .indentLines(1)

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
            .indentLines(1)
            .trimmingCharacters(in: CharacterSet.newlines)

        serviceDefinition += """
            \(accessControl) struct \(serviceName): APIInitialize {
            \(properties)

            \(initMethod)

            \(requestHelpers)

            \(apiFunctions)
            }

            """
        return serviceDefinition
    }
}
