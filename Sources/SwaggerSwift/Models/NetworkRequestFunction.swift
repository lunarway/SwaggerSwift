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
    let returnType: String?
    let consumes: NetworkRequestFunctionConsumes

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

    func toSwift(swaggerFile: SwaggerFile) -> String {
        let arguments = parameters.map { "\($0.name): \($0.typeName.toString(required: $0.required))" }.joined(separator: ", ")
        let returnStatement: String
        if let returnType = returnType {
            returnStatement = " -> \(returnType)"
        } else {
            returnStatement = ""
        }

        let declaration = """
@discardableResult
public func \(functionName)(\(arguments)) \(`throws` ? "throws" : "") \(returnStatement) {
"""

        let servicePath = self.servicePath
            .replacingOccurrences(of: "{", with: "\\(")
            .replacingOccurrences(of: "}", with: ")")

        let queryStatement: String
        if queries.count > 0 {
            let queryElements = "[" + queries.map { "URLQueryItem(name: \"\($0.fieldName)\", value: \($0.fieldName))" }.joined(separator: ", ") + "]"
            queryStatement = "\n    urlComponents.queryItems = \(queryElements)\n"
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

        let bodyInjection: String?
        switch consumes {
        case .json:
            headerStatements = "request.addValue(\"application/json\", forHTTPHeaderField: \"Content-Type\")"
            if parameters.contains(where: { $0.name == "body" }) {
                bodyInjection = "request.httpBody = try? JSONEncoder().encode(body)"
            } else {
                bodyInjection = ""
            }
        case .multiPartFormData:
            headerStatements = "request.addValue(\"multipart/form-data\", forHTTPHeaderField: \"Content-Type\")"
            bodyInjection = ""
        }


        let responseTypes = self.responseTypes.map { $0.print() }.joined(separator: "\n").replacingOccurrences(of: "\n", with: "\n            ")

        return """
\(declaration)
    let path = "\(servicePath)"
    let urlString = "\\(baseUrl)\\(path)"

    \(queryStatement.count > 0 ? "var" : "let") urlComponents = URLComponents(string: urlString)!
    \(queryStatement)
    let url = urlComponents.url!
    var request = URLRequest(url: url)
    request.httpMethod = "\(httpMethod.uppercased())"
    \(globalHeaderInitialisation)
    \(headerStatements)

    \(bodyInjection ?? "")

    request = interceptor?.networkWillPerformRequest(request) ?? request
    let task = urlSession.dataTask(with: request) { (data, response, error) in
        if let error = error {
            self.interceptor?.networkDidPerformRequest(.failed(error))
            completionHandler(.failure(.requestFailed(error: error)))
        } else if let data = data {
            guard let httpResponse = response as? HTTPURLResponse else {
                completionHandler(.failure(ServiceError.clientError(reason: "Returned response object wasnt a HTTP URL Response as expected, but was instead a \\(String(describing: response))")))
                return
            }

            self.interceptor?.networkDidPerformRequest(.success(httpResponse, data))

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
    }
}
