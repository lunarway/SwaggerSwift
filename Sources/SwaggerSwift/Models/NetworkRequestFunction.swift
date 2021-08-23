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

    func toSwift(swaggerFile: SwaggerFile, embedded: Bool) -> String {
        let arguments = parameters.map { "\($0.name.variableNameFormatted): \($0.typeName.toString(required: $0.required))" }.joined(separator: ", ")

        let servicePath = self.servicePath
            .replacingOccurrences(of: "{", with: "\\(")
            .replacingOccurrences(of: "}", with: ")")

        let queryStatement: String
        if queries.count > 0 {
            let queryItems = queries.map {
                if $0.isOptional {
                    return """
                        if let \($0.fieldValue) = \($0.fieldValue) {
                            queryItems.append(URLQueryItem(name: \"\($0.fieldName)\", value: \($0.fieldValue)))
                        }
                        """
                } else {
                    return "queryItems.append(URLQueryItem(name: \"\($0.fieldName)\", value: \($0.fieldValue)))"
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

        let swaggerGlobalHeaders = swaggerFile.globalHeaders ?? []

        var globalHeaders = swaggerGlobalHeaders
            .map { NetworkRequestFunctionHeaderField(headerName: $0, required: true) }
            .map { """
request.addValue(globalHeaders.\($0.headerModelName), forHTTPHeaderField: \"\($0.fieldName)\")
"""
            }.joined(separator: "\n")

        if globalHeaders.count > 0 {
            globalHeaders = "let globalHeaders = self.headerProvider()\n" + globalHeaders
        }

        let globalHeaderInitialisation = globalHeaders.replacingOccurrences(of: "\n", with: "\n    ")

        var headerStatements = headers
            .filter { !swaggerGlobalHeaders.map { $0.lowercased() }.contains($0.fieldName.lowercased()) }
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
            }.joined(separator: "\n\(defaultSpacing)")

        var bodyInjection: String = ""
        if let body = parameters.first(where: { $0.in == .body }) {
            bodyInjection += "request.httpBody = try? JSONEncoder().encode(\(body.name))\n"
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
                \n
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
            headerStatements += "\n    request.addValue(\"application/json\", forHTTPHeaderField: \"Content-Type\")"
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
        declaration += "public func \(functionName)(\(arguments)) \(`throws` ? "throws" : "") \(returnStatement) {"

        let responseTypes = self.responseTypes.map { $0.print() }.joined(separator: "\n").replacingOccurrences(of: "\n", with: "\n            ")

        var body =
            """
\(declaration)
    let endpointUrl = self.baseUrl().appendingPathComponent("\(servicePath)")

    \(queryStatement.count > 0 ? "var" : "let") urlComponents = URLComponents(url: endpointUrl, resolvingAgainstBaseURL: true)!
    \(queryStatement)
    let requestUrl = urlComponents.url!
    var request = URLRequest(url: requestUrl)
    request.httpMethod = "\(httpMethod.uppercased())"
    \(globalHeaderInitialisation)
    \(headerStatements)

    \(bodyInjection.replacingOccurrences(of: "\n", with: "\n\(defaultSpacing)"))

    request = interceptor?.networkWillPerformRequest(request) ?? request
    let task = urlSession().\(urlSessionMethodName) { (data, response, error) in
        if let interceptor = self.interceptor, interceptor.networkDidPerformRequest(urlRequest: request, urlResponse: response, data: data, error: error) == false {
            return
        }

        if let error = error {
            completionHandler(.failure(.requestFailed(error: error)))
        } else if let data = data {
            guard let httpResponse = response as? HTTPURLResponse else {
                completionHandler(.failure(ServiceError.clientError(reason: "Returned response object wasnt a HTTP URL Response as expected, but was instead a \\(String(describing: response))")))
                return
            }

            switch httpResponse.statusCode {
            \(responseTypes)
            default:
                let result = String(data: data, encoding: .utf8) ?? ""
                let error = NSError(domain: "OnboardingService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: result])
                completionHandler(.failure(.requestFailed(error: error)))
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
