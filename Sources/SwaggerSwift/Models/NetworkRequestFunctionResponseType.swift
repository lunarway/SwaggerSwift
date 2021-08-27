private func toHttpCodeName(code: Int) -> String {
    return HTTPStatusCodes(rawValue: code)!.name
}

enum NetworkRequestFunctionResponseType {
    case textPlain(HTTPStatusCodes, Bool)
    case applicationJson(HTTPStatusCodes, Bool, String)
    case void(HTTPStatusCodes, Bool)

    var statusCode: HTTPStatusCodes {
        switch self {
        case .textPlain(let statusCode, _):
            return statusCode
        case .applicationJson(let statusCode, _, _):
            return statusCode
        case .void(let statusCode, _):
            return statusCode
        }
    }

    func print() -> String {
        let failed = !statusCode.isSuccess
        let swiftResult = failed ? "failure" : "success"

        let resultType: (String, Bool) -> String = { resultType, enumBased -> String in
            let resultBlock = resultType.count == 0 ? "" : "(\(resultType))"
            if failed {
                return enumBased ? ".backendError(error: .\(statusCode.name)\(resultBlock))" : ".backendError(error: \(resultType))"
            } else {
                return enumBased ? ".\(statusCode.name)\(resultBlock)" : resultType
            }
        }

        switch self {
        case .textPlain(let statusCode, let resultIsEnum):
            return """
case \(statusCode.rawValue):
    let result = String(data: data, encoding: .utf8) ?? ""
    completionHandler(.\(swiftResult)(\(resultType("result", resultIsEnum))))
"""
        case .applicationJson(let statusCode, let resultIsEnum, let responseType):
            return """
case \(statusCode.rawValue):
    do {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom(dateDecodingStrategy)
        let result = try decoder.decode(\(responseType).self, from: data)

        completionHandler(.\(swiftResult)(\(resultType("result", resultIsEnum))))
    } catch let error {
        completionHandler(.failure(.requestFailed(error: error)))
    }
"""
        case .void(let statusCode, let resultIsEnum):
            if resultIsEnum {
                return """
case \(statusCode.rawValue):
    completionHandler(.\(swiftResult)(\(resultType("", resultIsEnum))))
"""
            } else {
                return """
case \(statusCode.rawValue):
    completionHandler(.\(swiftResult)(\(resultType("()", resultIsEnum))))
"""
            }
        }
    }
}
