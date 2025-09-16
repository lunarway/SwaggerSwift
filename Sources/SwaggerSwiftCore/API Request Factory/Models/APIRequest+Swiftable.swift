import Foundation
import SwaggerSwiftML

extension APIRequest {
    /// The arguments of the function, e.g. "myValue: String, myOtherValue: Int"
    private var functionArguments: String {
        parameters.map {
            let paramName = $0.name.variableNameFormatted
            let typeName = $0.typeName.toString(required: $0.required)

            let defaultValue: String
            if !$0.required {
                defaultValue = " = nil"
            } else {
                defaultValue = ""
            }

            return "\(paramName): \(typeName)\(defaultValue)"
        }.joined(separator: ", ")
    }

    private func makeRequestFunction(
        serviceName: String?,
        swaggerFile: SwaggerFile,
        accessControl: String
    ) -> String {
        let servicePath = self.servicePath.split(separator: "/")
            .map {
                let path = String($0)
                    .replacingOccurrences(of: "{", with: "")
                    .replacingOccurrences(of: "}", with: "")

                if $0.contains("{") {
                    return "\\(\(path.variableNameFormatted))"
                } else {
                    return path
                }
            }.joined(separator: "/")

        // Build request-specific headers dictionary
        let requestHeaders = headers.map { header in
            let headersName = headers.filter { $0.isRequired }.count > 0 ? "headers" : "headers?"
            if header.isRequired {
                return "\"\(header.fullHeaderName)\": \(headersName).\(header.swiftyName)"
            } else {
                return "\"\(header.fullHeaderName)\": \(headersName).\(header.swiftyName)"
            }
        }.joined(separator: ",\n                ")

        // Build request body
        let requestBody: String
        if let body = parameters.first(where: { $0.in == .body }) {
            requestBody = """
                let jsonEncoder = JSONEncoder()
                jsonEncoder.dateEncodingStrategy = .iso8601
                let requestBody = try? jsonEncoder.encode(\(body.name))
                """
        } else {
            requestBody = "let requestBody: Data? = nil"
        }

        // Handle form data if present
        let formDataBody: String
        let contentType: String?
        if parameters.contains(where: { $0.in == .formData }) {
            formDataBody = """
                let boundary = "Boundary-\\(UUID().uuidString)"
                var requestData = Data()

                \(parameters.filter { $0.in == .formData }.compactMap {
                    switch $0.typeName {
                    case .string:
                        return """
                            if let data = \($0.variableName).data(using: .utf8) {
                                requestData.append(FormData(data: data).toRequestData(named: "\($0.name)", using: boundary))
                            }
                            """
                    case .int:
                        fatalError("not implemented")
                    case .double:
                        fatalError("not implemented")
                    case .float:
                        fatalError("not implemented")
                    case .boolean:
                        fatalError("not implemented")
                    case .int64:
                        fatalError("not implemented")
                    case .array:
                        fatalError("not implemented")
                    case .enumeration(let typeName): fallthrough
                    case .object(let typeName):
                        if typeName == "FormData" {
                            return
                                "requestData.append(\($0.name).toRequestData(named: \"\($0.name)\", using: boundary))"
                        } else if $0.isEnum {
                            return """
                                if let data = \($0.name).rawValue.data(using: .utf8) {
                                    requestData.append(FormData(data: data).toRequestData(named: "\($0.name)", using: boundary))
                                }
                                """
                        } else {
                            fatalError("not implemented")
                        }
                    case .date:
                        fatalError("not implemented")
                    case .void:
                        fatalError("not implemented")
                    case .typeAlias:
                        fatalError("not implemented")
                    }
                }.joined(separator: "\n"))

                if let endBoundaryData = "--\\(boundary)--".data(using: .utf8) {
                    requestData.append(endBoundaryData)
                }
                let requestBody = requestData
                """
            contentType = "multipart/form-data; boundary=\\(boundary)"
        } else {
            formDataBody = ""
            contentType = consumes == .json ? "application/json" : nil
        }

        let responseTypes = self.responseTypes
            .map {
                $0.print(
                    apiName: serviceName ?? "",
                    errorType: returnType.failureType.toString(required: true)
                )
            }
            .joined(separator: "\n")

        var functionDeclaration: String = "private func _\(functionName)"
        if swaggerFile.onlyAsync && !isInternalOnly {
            functionDeclaration = "\(accessControl) func \(functionName)"
        }

        // Build the request headers dictionary
        let headersDict = requestHeaders.isEmpty ? "[:]" : """
            [
                \(requestHeaders)
            ]
            """

        return """
            \(functionDeclaration)(\(functionArguments)) async throws(\(returnType.failureType.toString(required: true))) -> \(returnType.successType.toString(required: true)) {
                \(queries.count > 0 ? "var" : "let") urlComponents = URLComponents(url: await baseUrlProvider().appendingPathComponent("\(servicePath)"), resolvingAgainstBaseURL: true)!
            \(queries.toQueryItems().indentLines(1))
                let requestUrl = urlComponents.url!
                
                \(requestBody)
                \(formDataBody)
                
                let requestBuilder = RequestBuilder(
                    baseUrlProvider: baseUrlProvider,
                    headerProvider: headerProvider,
                    interceptor: interceptor
                )
                
                let request = await requestBuilder.buildRequest(
                    path: "\(servicePath)",
                    method: "\(httpMethod.rawValue)",
                    headers: \(headersDict),
                    body: requestBody,
                    contentType: \(contentType != nil ? "\"\(contentType ?? "")\"" : "nil")
                )

                let networkExecutor = NetworkExecutor(
                    urlSession: urlSession,
                    interceptor: interceptor
                )
                
                let (data, httpResponse) = try await networkExecutor.executeRequest(request)

                let decoder = ResponseDecoder()

                switch httpResponse.statusCode {
            \(responseTypes.indentLines(1))
                default:
                    let result = String(data: data, encoding: .utf8) ?? ""
                    let error = NSError(domain: "\(serviceName ?? "Generic")", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: result])
                    throw .requestFailed(error: error)
                }
            }

            """
    }

    func toSwift(
        serviceName: String?,
        swaggerFile: SwaggerFile,
        embedded: Bool,
        accessControl: String,
        packagesToImport: [String]
    ) -> String {
        var documentation = """
            \(description?.documentationFormat() ?? "/// No description provided")
            /// - Endpoint: `\(self.httpMethod.rawValue.uppercased()) \(self.servicePath)`
            """

        if parameters.count > 0 {
            documentation += "\n"
            documentation += """
                /// - Parameters:
                \(parameters.map { "///   - \($0.variableName): \($0.description?.replacingOccurrences(of: "\n", with: ". ").replacingOccurrences(of: "..", with: ".") ?? "No description")" }.joined(separator: "\n"))
                """
        }

        var body: String = ""

        if isInternalOnly {
            body += "#if DEBUG\n"
        }

        if isDeprecated {
            body += "\n"
            body += "@available(*, deprecated)\n"
        }

        body += documentation + "\n"

        body += makeRequestFunction(
            serviceName: serviceName,
            swaggerFile: swaggerFile,
            accessControl: accessControl
        )

        if swaggerFile.onlyAsync == false {
            if isDeprecated {
                body += "\n"
                body += "@available(*, deprecated)\n"
            }

            body += documentation

            body += "\n"

            body += """
                        \(accessControl) func \(functionName)(\(functionArguments)\(functionArguments.isEmpty ? "" : ", ")completion: @Sendable @escaping (Result<\(returnType.successType.toString(required: true)), \(returnType.failureType.toString(required: true))>) -> Void = { _ in }) {
                            _Concurrency.Task {
                                do {

                """

            if returnType.successType.toString(required: true) == "Void" {
                body += """
                                try await _\(functionName)(\(parameters.map { "\($0.name.variableNameFormatted): \($0.name.variableNameFormatted)" }.joined(separator: ", ")))
                                completion(.success(()))

                    """
            } else {
                body += """
                                let result = try await _\(functionName)(\(parameters.map { "\($0.name.variableNameFormatted): \($0.name.variableNameFormatted)" }.joined(separator: ", ")))
                                completion(.success(result))

                    """
            }

            body += """
                        } catch let error {
                            let error = error as! \(returnType.failureType.toString(required: true)) 
                            completion(.failure(error))
                        }
                    }
                }

                """
        }

        if swaggerFile.onlyAsync == false {
            if isDeprecated {
                body += "\n"
                body += "@available(*, deprecated)\n"
            }

            body += documentation

            body += "\n"

            if returnType.successType.toString(required: true) != "Void" {
                body += "@discardableResult\n"
            }

            body +=
                """
                \(accessControl) func \(functionName)(\(functionArguments)) async throws(\(returnType.failureType.toString(required: true))) -> \(returnType.successType.toString(required: true)) {
                    try await _\(functionName)(\(parameters.map { "\($0.name.variableNameFormatted): \($0.name.variableNameFormatted)" }.joined(separator: ", ")))
                }

                """
        }

        if isInternalOnly {
            body += "#endif\n"
        }

        return body
    }
}

extension String {
    fileprivate func documentationFormat() -> String {
        trimmingCharacters(in: CharacterSet.newlines).components(separatedBy: "\n").map { "/// \($0)" }
            .joined(separator: "\n")
    }

    fileprivate func addNewlinesIfNonEmpty(_ count: Int = 1) -> String {
        if self.count > 0 {
            return self + String(repeating: "\n", count: count)
        } else {
            return self
        }
    }
}
