private func toHttpCodeName(code: Int) -> String {
    return HTTPStatusCodes(rawValue: code)!.name
}

enum NetworkRequestFunctionResponseType {
    case textPlain(HTTPStatusCodes, Bool)
    case object(HTTPStatusCodes, Bool, _ typeName: String)
    case int(HTTPStatusCodes, Bool)
    case array(HTTPStatusCodes, Bool, _ typeName: String)
    case double(HTTPStatusCodes, Bool)
    case float(HTTPStatusCodes, Bool)
    case boolean(HTTPStatusCodes, Bool)
    case int64(HTTPStatusCodes, Bool)
    case void(HTTPStatusCodes, Bool)

    var statusCode: HTTPStatusCodes {
        switch self {
        case .textPlain(let statusCode, _):
            return statusCode
        case .object(let statusCode, _, _):
            return statusCode
        case .void(let statusCode, _):
            return statusCode
        case .int(let statusCode, _):
            return statusCode
        case .double(let statusCode, _):
            return statusCode
        case .float(let statusCode, _):
            return statusCode
        case .boolean(let statusCode, _):
            return statusCode
        case .int64(let statusCode, _):
            return statusCode
        case .array(let statusCode, _, _):
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
        case .object(let statusCode, let resultIsEnum, let responseType):
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
        case .int(let statusCode, _):
            return """
case \(statusCode.rawValue):
    if let stringValue = String(data: data, encoding: .utf8), let value = Int(stringValue) {
        completionHandler(.success(value))
    } else {
        completionHandler(.failure(.clientError(reason: "Failed to convert backend result to expected type"))
    }
"""
        case .double(let statusCode, _):
            return """
case \(statusCode.rawValue):
    if let stringValue = String(data: data, encoding: .utf8), let value = Double(stringValue) {
        completionHandler(.success(value))
    } else {
        completionHandler(.failure(.clientError(reason: "Failed to convert backend result to expected type"))
    }
"""
        case .float(let statusCode, _):
            return """
case \(statusCode.rawValue):
    if let stringValue = String(data: data, encoding: .utf8), let value = Float(stringValue) {
        completionHandler(.success(value))
    } else {
        completionHandler(.failure(.clientError(reason: "Failed to convert backend result to expected type"))
    }
"""
        case .boolean(let statusCode, _):
            return """
case \(statusCode.rawValue):
    if let stringValue = String(data: data, encoding: .utf8), let value = Bool(stringValue) {
        completionHandler(.success(value))
    } else {
        completionHandler(.failure(.clientError(reason: "Failed to convert backend result to expected type"))
    }
"""
        case .int64(let statusCode, _):
            return """
case \(statusCode.rawValue):
    if let stringValue = String(data: data, encoding: .utf8), let value = Int64(stringValue) {
        completionHandler(.success(value))
    } else {
        completionHandler(.failure(.clientError(reason: "Failed to convert backend result to expected type"))
    }
"""
        case .array(let statusCode, let resultIsEnum, let innerType):
            return """
case \(statusCode.rawValue):
    do {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom(dateDecodingStrategy)
        let result = try decoder.decode([\(innerType)].self, from: data)

        completionHandler(.\(swiftResult)(\(resultType("result", resultIsEnum))))
    } catch let error {
        completionHandler(.failure(.requestFailed(error: error)))
    }
"""
        }
    }
}
