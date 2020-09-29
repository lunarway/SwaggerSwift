// describes a single network request function
struct NetworkRequestFunction {
    let description: String?
    let functionName: String
    let parameters: [FunctionParameter]
    let `throws`: Bool
    let returnType: String?

    let httpMethod: String
    let servicePath: String

    let queries: [QueryElement]
    let headers: [(String, String, Bool)]
    let responseTypes: [NetworkRequestFunctionResponseType]
}

extension NetworkRequestFunction: Swiftable {
    var typeName: String {
        return ""
    }

    func toSwift() -> String {
        let arguments = parameters.map { "\($0.name): \($0.typeName.toString())" }.joined(separator: ", ")
        let returnStatement: String
        if let returnType = returnType {
            returnStatement = " -> \(returnType)"
        } else {
            returnStatement = ""
        }

        let declaration = """
@discardableResult
func \(functionName)(\(arguments)) throws \(returnStatement) {
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

        let headerStatements = headers.map {
            if $0.2 {
                return "request.addValue(headers.\($0.0), forHTTPHeaderField: \"\($0.1)\")"
            } else {
                return """
if let \($0.0) = headers.\($0.0) {
    request.addValue(\($0.0), forHTTPHeaderField: \"\($0.1)\")
}
"""
            }
        }.joined(separator: "\n").replacingOccurrences(of: "\n", with: "\n    ")

        let responseTypes = self.responseTypes.map { $0.print() }.joined(separator: "\n").replacingOccurrences(of: "\n", with: "\n            ")

        return """
\(declaration)
    let path = "\(servicePath)"
    let urlString = "\\(baseUrl)\\(path)"

    guard \(queryStatement.count > 0 ? "var" : "let") urlComponents = URLComponents(string: urlString) else { throw ServiceError<Void>.clientError(reason: "Failed to create URL components") }
    \(queryStatement)
    guard let url = urlComponents.url else { throw ServiceError<Void>.clientError(reason: "Failed to create URL") }
    var request = URLRequest(url: url)
    request.httpMethod = "\(httpMethod.uppercased())"
    \(headerStatements)

    let task = urlSession.dataTask(with: request) { (data, response, error) in
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
    }
}
