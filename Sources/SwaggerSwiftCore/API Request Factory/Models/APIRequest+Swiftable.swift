import Foundation
import SwaggerSwiftML

extension APIRequest {
    func toSwift(serviceName: String?, swaggerFile: SwaggerFile, embedded: Bool, accessControl: String, packagesToImport: [String]) -> String {
        let arguments = parameters.map {
            "\($0.name.variableNameFormatted): \($0.typeName.toString(required: $0.required))\($0.required ? "" : " = nil")"
        }.joined(separator: ", ")

        let servicePath = self.servicePath.split(separator: "/").map {
            let path = String($0)
                .replacingOccurrences(of: "{", with: "")
                .replacingOccurrences(of: "}", with: "")

            if $0.contains("{") {
                return "\\(\(path.variableNameFormatted))"
            } else {
                return path
            }
        }.joined(separator: "/")

        let queryStatement: String = queries.toQueryItems()

        var globalHeaders = [String]()
        if let globalHeaderFields = swaggerFile.globalHeaders, globalHeaderFields.count > 0 {
            globalHeaders.append("let globalHeaders = self.headerProvider()")
            globalHeaders.append("globalHeaders.add(to: &request)")
        }

        var headerStatements: [String] = headers
            .sorted(by: { $0.swiftyName < $1.swiftyName })
            .filter { !(swaggerFile.globalHeaders ?? []).map { $0.lowercased() }.contains($0.fullHeaderName.lowercased()) }
            .map {
                if $0.isRequired {
                    return "request.addValue(headers.\($0.swiftyName), forHTTPHeaderField: \"\($0.fullHeaderName)\")"
                } else {
                    return """
if let \(($0.swiftyName)) = headers.\($0.swiftyName) {
        request.addValue(\($0.swiftyName), forHTTPHeaderField: \"\($0.fullHeaderName)\")
    }
"""
                }
            }

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

        let returnStatement: String
        let urlSessionMethodName: String
        switch consumes {
        case .json:
            urlSessionMethodName = "dataTask(with: request)"
            headerStatements.append("request.addValue(\"application/json\", forHTTPHeaderField: \"Content-Type\")")
            returnStatement = " -> URLSessionDataTask"

        case .formUrlEncoded: fallthrough
        case .multiPartFormData:
            urlSessionMethodName = "uploadTask(with: request, from: requestData as Data)"
            returnStatement = " -> URLSessionUploadTask"
        }

        var declaration = ""
        if isDeprecated {
            declaration += "@available(*, deprecated)\n"
        }

        if isInternalOnly {
            declaration += "#if DEBUG\n"
        }

        declaration += "@discardableResult\n"

        declaration += """
        \(description?.documentationFormat() ?? "/// No description provided")
        /// - Endpoint: \(self.httpMethod.rawValue.uppercased()) \(self.servicePath)
        /// - Parameters:
        \(parameters.map { "///   - \($0.variableName): \($0.description?.replacingOccurrences(of: "\n", with: ". ").replacingOccurrences(of: "..", with: ".") ?? "No description")" }.joined(separator: "\n"))
        /// - Returns: the URLSession task. This can be used to cancel the request.

        """

        declaration += "\(accessControl) func \(functionName)(\(arguments))\(`throws` ? " throws" : "")\(returnStatement) {"

        let responseTypes = self.responseTypes.map { $0.print() }.joined(separator: "\n").replacingOccurrences(of: "\n", with: "\n            ")

        let requestPart = (globalHeaders.joined(separator: "\n").addNewlinesIfNonEmpty(2)
                           + headerStatements.joined(separator: "\n").addNewlinesIfNonEmpty(2)
                           + bodyInjection.addNewlinesIfNonEmpty(2))
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .indentLines(1)
            .addNewlinesIfNonEmpty()

        var body =
            """
\(declaration)
    let endpointUrl = self.baseUrlProvider().appendingPathComponent("\(servicePath)")

    \(queryStatement.count > 0 ? "var" : "let") urlComponents = URLComponents(url: endpointUrl, resolvingAgainstBaseURL: true)!
\(queryStatement.indentLines(1))
    let requestUrl = urlComponents.url!
    var request = URLRequest(url: requestUrl)
    request.httpMethod = "\(httpMethod.rawValue.uppercased())"
\(requestPart)
    request = interceptor?.networkWillPerformRequest(request) ?? request
    let task = urlSession().\(urlSessionMethodName) { (data, response, error) in
        let completion: (Data?, URLResponse?, Error?) -> Void = { (data, response, error) in
            if let error = error {
                completion(.failure(.requestFailed(error: error)))
            } else if let data = data {
                guard let httpResponse = response as? HTTPURLResponse else {
                    completion(.failure(ServiceError.clientError(reason: "Returned response object wasnt a HTTP URL Response as expected, but was instead a \\(String(describing: response))")))
                    return
                }

                switch httpResponse.statusCode {
                \(responseTypes)
                default:
                    let result = String(data: data, encoding: .utf8) ?? ""
                    let error = NSError(domain: "\(serviceName ?? "Generic")", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: result])
                    completion(.failure(.requestFailed(error: error)))
                }
            }
        }
        if let interceptor = self.interceptor {
          interceptor.networkDidPerformRequest(urlRequest: request, urlResponse: response, data: data, error: error) { result in
             switch result {
              case .success:
                  completion(data, response, error)
              case .failure(let error):
                  completion(nil, nil, error)
             }
          }
        } else {
            completion(data, response, error)
        }
    }

    task.resume()

    return task
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
