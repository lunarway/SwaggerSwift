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

    private var functionReturnType: String {
        returnType.typeName.toString(required: true)
    }

    private func makeRequestFunction(serviceName: String?, swaggerFile: SwaggerFile) -> String {
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

        var globalHeaders = [String]()
        if swaggerFile.globalHeaders.count > 0 {
            globalHeaders.append("let globalHeaders = self.headerProvider()")
            globalHeaders.append("globalHeaders.add(to: &request)")
        }

        let uniquelyGlobalHeaders = swaggerFile.globalHeaders.filter { globalHeaderName in headers.contains(where: { $0.fullHeaderName == globalHeaderName }) == false }

        let allHeaders = headers + uniquelyGlobalHeaders.map {
            APIRequestHeaderField(headerName: $0, isRequired: false) // not required as they are default from the global header provider
        }

        let headersName = headers.filter { $0.isRequired }.count > 0 ? "headers" : "headers?"

        let setHeaderValues: [String] = allHeaders
            .sorted(by: { $0.swiftyName < $1.swiftyName })
            .map {
                if $0.isRequired {
                    return "request.setValue(\(headersName).\($0.swiftyName), forHTTPHeaderField: \"\($0.fullHeaderName)\")"
                } else {
                    return """
if let \(($0.swiftyName)) = \(headersName).\($0.swiftyName) {
    request.setValue(\($0.swiftyName), forHTTPHeaderField: \"\($0.fullHeaderName)\")
}
"""
                }
            }

        var headerStatements = setHeaderValues

        var bodyInjection: String = ""
        if let body = parameters.first(where: { $0.in == .body }) {
            bodyInjection += """
                let jsonEncoder = JSONEncoder()
                jsonEncoder.dateEncodingStrategy = .iso8601
                request.httpBody = try? jsonEncoder.encode(\(body.name))
                """
        }

        if parameters.contains(where: { $0.in == .formData }) {
            bodyInjection += """
                let boundary = "Boundary-\\(UUID().uuidString)"
                request.setValue("multipart/form-data; boundary=\\(boundary)", forHTTPHeaderField: "Content-Type")

                var requestData = Data()

                """

            bodyInjection += parameters.filter { $0.in == .formData }.compactMap {
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
                        return "requestData.append(\($0.name).toRequestData(named: \"\($0.name)\", using: boundary))"
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
            }.joined(separator: "\n")

            bodyInjection += """

                if let endBoundaryData = "--\\(boundary)--".data(using: .utf8) {
                    requestData.append(endBoundaryData)
                }
                """
        }

        let urlSessionMethodName: String
        switch consumes {
        case .json:
            urlSessionMethodName = "data(for: request)"
            headerStatements.append("request.setValue(\"application/json\", forHTTPHeaderField: \"Content-Type\")")

        case .formUrlEncoded: fallthrough
        case .multiPartFormData:
            urlSessionMethodName = "upload(for: request, from: requestData as Data)"
        }

        let requestPart = (globalHeaders.joined(separator: "\n").addNewlinesIfNonEmpty(2)
                           + headerStatements.joined(separator: "\n").addNewlinesIfNonEmpty(2)
                           + bodyInjection.addNewlinesIfNonEmpty(2))
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .indentLines(1)
            .addNewlinesIfNonEmpty()

        let responseTypes = self.responseTypes
            .map { $0.print(apiName: serviceName ?? "") }
            .joined(separator: "\n")

        return """
private func _\(functionName)(\(functionArguments)) async -> \(functionReturnType) {
    let endpointUrl = baseUrlProvider().appendingPathComponent("\(servicePath)")

    \(queries.count > 0 ? "var" : "let") urlComponents = URLComponents(url: endpointUrl, resolvingAgainstBaseURL: true)!
\(queries.toQueryItems().indentLines(1))
    let requestUrl = urlComponents.url!
    var request = URLRequest(url: requestUrl)
    request.httpMethod = "\(httpMethod.rawValue.uppercased())"
\(requestPart)
    request = interceptor?.networkWillPerformRequest(request) ?? request

    let data: Data
    let response: URLResponse
    do {
        (data, response) = try await urlSession().\(urlSessionMethodName)
    } catch {
        return .failure(.requestFailed(error: error))
    }

    if let interceptor {
        do {
            try await interceptor.networkDidPerformRequest(urlRequest: request, urlResponse: response, data: data, error: nil)
        } catch {
            return .failure(.requestFailed(error: error))
        }
    }

    guard let httpResponse = response as? HTTPURLResponse else {
        let error = NSError(domain: "\(serviceName ?? "Generic")", code: 0, userInfo: [NSLocalizedDescriptionKey: "Returned response object wasnt a HTTP URL Response as expected, but was instead a \\(String(describing: response))"])
        return .failure(.requestFailed(error: error))
    }

    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .custom(dateDecodingStrategy)

    switch httpResponse.statusCode {
\(responseTypes.indentLines(1))
    default:
        let result = String(data: data, encoding: .utf8) ?? ""
        let error = NSError(domain: "\(serviceName ?? "Generic")", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: result])
        return .failure(.requestFailed(error: error))
    }
}

"""
    }

    func toSwift(serviceName: String?, swaggerFile: SwaggerFile, embedded: Bool, accessControl: String, packagesToImport: [String]) -> String {
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

        body += makeRequestFunction(serviceName: serviceName, swaggerFile: swaggerFile)

        if isDeprecated {
            body += "\n"
            body += "@available(*, deprecated)\n"
        }

        body += documentation

        body += "\n"

        body += """
        \(accessControl) func \(functionName)(\(functionArguments)\(functionArguments.isEmpty ? "" : ", ")completion: @Sendable @escaping (\(functionReturnType)) -> Void = { _ in }) {
            _Concurrency.Task {
                let result = await _\(functionName)(\(parameters.map { "\($0.name.variableNameFormatted): \($0.name.variableNameFormatted)" }.joined(separator: ", ")))
                completion(result)
            }
        }

        """

        if isDeprecated {
            body += "\n"
            body += "@available(*, deprecated)\n"
        }

        body += documentation

        body += "\n"

        body +=
        """
        @discardableResult
        \(accessControl) func \(functionName)(\(functionArguments)) async -> \(functionReturnType) {
            await _\(functionName)(\(parameters.map { "\($0.name.variableNameFormatted): \($0.name.variableNameFormatted)" }.joined(separator: ", ")))
        }

        """

        if isInternalOnly {
            body += "#endif\n"
        }

        return body
    }
}

private extension String {
    func documentationFormat() -> String {
        trimmingCharacters(in: CharacterSet.newlines).components(separatedBy: "\n").map { "/// \($0)" }.joined(separator: "\n")
    }

    func addNewlinesIfNonEmpty(_ count: Int = 1) -> String {
        if self.count > 0 {
            return self + String(repeating: "\n", count: count)
        } else {
            return self
        }
    }
}
