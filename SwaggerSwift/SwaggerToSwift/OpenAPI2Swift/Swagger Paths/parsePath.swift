import SwaggerSwiftML

func parsePath(baseUrl: String?, httpMethod: String, endpoint: String, serviceName: String, path: Path, request: Operation) -> SwiftMethod {
    let allParameters = (path.parameters ?? []) + (request.parameters ?? [])

    guard let returnType = request.responses[200] else {
        fatalError("There are not set an HTTP 200 response - the tool would then need to support some other response")
    }
    
    let returnValue: String
    if let schema = returnType.schema {
        switch schema.value {
        case .reference(let ref):
            returnValue = ref.components(separatedBy: "/").last!
        case .node(let node):
            returnValue = getType(from: node.type!, format: node.format, items: node.items)!
        }
    } else {
        returnValue = "Void"
    }

    let params = allParameters.map { params -> Parameter in
        switch params {
        case .reference(let ref):
            assert(swagger.parameters != nil, "There cant be a reference to a parameter if the parameter cant be found")
            let paramName = ref.components(separatedBy: "/").last! // TODO: It is quite volatile that the reference path just gets ignored
            return swagger.parameters![paramName]!
        case .node(let node):
            return node
        }
    }.map { param -> SwiftMethodParameter in
        let name: String = param.name.replacingOccurrences(of: "X-", with: "")
        let type: String = param.swiftType(definitions: swagger.definitions)
        return SwiftMethodParameter(name: name, type: type)
    } + [SwiftMethodParameter(name: "completionHandler", type: "@escaping (Swift.Result<\(returnValue), NetworkError>) -> Void")]

    let decodeJsonCode = """
    do {
        guard let data = data else { completionHandler(.failure(.technical)); return }
        let object = try JSONDecoder().decode(\(returnValue).self, from: data)
        completionHandler(.success(object))
    } catch let ex {
        completionHandler(.failure(.invalidResponse(ex)))
    }
    """

    let decodeString = """
    guard let data = data else { completionHandler(.failure(.technical)); return }
    guard let result = String(data: data, encoding: .utf8) else {
        completionHandler(.failure(.invalidResponse(NSError(domain: "LunarWayOnboardingAPI", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to parse string to data"]))))
        return
    }
    completionHandler(.success(result))
    """

    let decodeVoid = """
    completionHandler(.success(()))
    """

    let decodeBlock: String
    switch returnValue {
    case "String":
        decodeBlock = decodeString
    case "Void":
        decodeBlock = decodeVoid
    default:
        decodeBlock = decodeJsonCode
    }


    return SwiftMethod(
        discardableResult: true,
        documentation: request.description,
        functionName: "\(httpMethod)\(serviceName)",
        parameters: params,
        returnValue: "URLSessionDataTask?",
        body: """
        guard let url = URL(string: \"\\(host)\(baseUrl ?? "")\(endpoint)\") else { return nil }
        var request = URLRequest(url: url)
        request.httpMethod = "\(httpMethod.uppercased())"
        let dataTask = urlSession.dataTask(with: request) { (data, response, error) in
            if let error = error {
                completionHandler(.failure(.requestError(error)))
            } else {
                guard let httpResponse = response as? HTTPURLResponse else { completionHandler(.failure(.technical)); return }

                switch httpResponse.statusCode {
                case 200:
\(decodeBlock)
                default:
                    completionHandler(.failure(.requestFailed(HTTPStatusCode(rawValue: httpResponse.statusCode)!)))
                }
            }
        }

        dataTask.resume()

        return dataTask
"""
    )
}
