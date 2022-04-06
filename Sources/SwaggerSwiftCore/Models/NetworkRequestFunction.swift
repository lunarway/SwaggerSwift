import Foundation
import SwaggerSwiftML

enum NetworkRequestFunctionConsumes {
    case json
    case multiPartFormData
}

// describes a single network request function
struct NetworkRequestFunction {
    let description: String?
    let functionName: String
    let parameters: [FunctionParameter]
    let `throws`: Bool
    let consumes: NetworkRequestFunctionConsumes
    let isInternalOnly: Bool
    let isDeprecated: Bool

    let httpMethod: String
    let servicePath: String

    /// URLQueryItems
    let queries: [QueryElement]
    let headers: [NetworkRequestFunctionHeaderField]
    let responseTypes: [NetworkRequestFunctionResponseType]
}

struct NetworkRequestFunctionHeaderField {
    /// is the field required
    let required: Bool
    /// The name of the field on the Swift type containing the object, e.g. xos
    let headerModelName: String
    /// The actual name of the header, e.g. x-OS
    let fieldName: String

    init(headerName: String, required: Bool) {
        self.headerModelName = makeHeaderFieldName(headerName: headerName)
        self.fieldName = headerName
        self.required = required
    }
}

extension NetworkRequestFunction: Swiftable {
    var typeName: String {
        return ""
    }

    func toSwift(serviceName: String?, swaggerFile: SwaggerFile, embedded: Bool, packagesToImport: [String]) -> String {
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

        let queryStatement: String
        if queries.count > 0 {
            let queryItems = queries.map {
                let fieldName = $0.fieldName.camelized
                if $0.isOptional {
                    let fieldValue: String
                    switch $0.valueType {
                    case .enum:
                        fieldValue = "\($0.fieldValue)?.rawValue"
                    case .date:
                        return """
                            if let \(fieldName)Value = \($0.fieldName) {
                                queryItems.append(URLQueryItem(name: \"\($0.fieldName)\", value: \(fieldName)Value))
                            }
                            """
                    default:
                        fieldValue = "\($0.fieldValue)"
                    }

                    return """
                        if let \(fieldName)Value = \(fieldValue) {
                            queryItems.append(URLQueryItem(name: \"\($0.fieldName)\", value: \(fieldName)Value))
                        }
                        """
                } else {
                    let fieldValue: String
                    switch $0.valueType {
                    case .enum:
                        fieldValue = "\($0.fieldValue).rawValue"
                    default:
                        fieldValue = "\($0.fieldValue)"
                    }

                    return "queryItems.append(URLQueryItem(name: \"\($0.fieldName)\", value: \(fieldValue)))"
                }
            }.joined(separator: "\n")

            queryStatement = """
                var queryItems = [URLQueryItem]()
                \(queryItems)
                urlComponents.queryItems = queryItems\n
                """
        } else {
            queryStatement = ""
        }

        var globalHeaders = [String]()
        if let globalHeaderFields = swaggerFile.globalHeaders, globalHeaderFields.count > 0 {
            globalHeaders.append("let globalHeaders = self.headerProvider()")
            globalHeaders.append("globalHeaders.add(to: &request)")
        }

        var headerStatements: [String] = headers
            .filter { !(swaggerFile.globalHeaders ?? []).map { $0.lowercased() }.contains($0.fieldName.lowercased()) }
            .map {
                if $0.required {
                    return "request.addValue(headers.\($0.headerModelName), forHTTPHeaderField: \"\($0.fieldName)\")"
                } else {
                    return """
if let \(($0.headerModelName)) = headers.\($0.headerModelName) {
        request.addValue(\(($0.headerModelName)), forHTTPHeaderField: \"\($0.fieldName)\")
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
                case .object(typeName: let typeName):
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
        /// - Endpoint: \(self.httpMethod.uppercased()) \(self.servicePath)
        /// - Parameters:
        \(parameters.map { "///   - \($0.variableName): \($0.description?.replacingOccurrences(of: "\n", with: ". ").replacingOccurrences(of: "..", with: ".") ?? "No description")" }.joined(separator: "\n"))
        /// - Returns: the URLSession task. This can be used to cancel the request.

        """

        declaration += "public func \(functionName)(\(arguments))\(`throws` ? " throws" : "")\(returnStatement) {"

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
    let endpointUrl = self.baseUrl().appendingPathComponent("\(servicePath)")

    \(queryStatement.count > 0 ? "var" : "let") urlComponents = URLComponents(url: endpointUrl, resolvingAgainstBaseURL: true)!
\(queryStatement.indentLines(1))
    let requestUrl = urlComponents.url!
    var request = URLRequest(url: requestUrl)
    request.httpMethod = "\(httpMethod.uppercased())"
\(requestPart)
    request = interceptor?.networkWillPerformRequest(request) ?? request
    let task = urlSession().\(urlSessionMethodName) { (data, response, error) in
        if let interceptor = self.interceptor, interceptor.networkDidPerformRequest(urlRequest: request, urlResponse: response, data: data, error: error) == false {
            return
        }

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
