/// A given response type for a API request. The response type is first and foremost the data type that is returned, and then the HTTP status code
enum APIRequestResponseType {
    case textPlain(HTTPStatusCode, Bool)
    case enumeration(HTTPStatusCode, Bool, typeName: String)
    case object(HTTPStatusCode, Bool, typeName: String)
    case int(HTTPStatusCode, Bool)
    case array(HTTPStatusCode, Bool, typeName: String)
    case double(HTTPStatusCode, Bool)
    case float(HTTPStatusCode, Bool)
    case boolean(HTTPStatusCode, Bool)
    case int64(HTTPStatusCode, Bool)
    case void(HTTPStatusCode, Bool)

    var statusCode: HTTPStatusCode {
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
        case .enumeration(let statusCode, _, _):
            return statusCode
        }
    }

    func print() -> String {
        let failed = !statusCode.isSuccess
        let swiftResult = failed ? "failure" : "success"

        let resultType: (String, Bool) -> String = { resultType, enumBased -> String in
            let resultBlock = resultType.count == 0 ? "" : "(\(resultType))"
            if failed {
                if enumBased {
                    return ".backendError(error: .\(statusCode.name)\(resultBlock))"
                } else {
                    return ".backendError(error: \(resultType))"
                }
            } else {
                return enumBased ? ".\(statusCode.name)\(resultBlock)" : resultType
            }
        }

        switch self {
        case .textPlain(let statusCode, let resultIsEnum):
            return """
case \(statusCode.rawValue):
    let result = String(data: data, encoding: .utf8) ?? ""
    completion(.\(swiftResult)(\(resultType("result", resultIsEnum))))
"""
        case .object(let statusCode, let resultIsEnum, let responseType):
            if responseType == "Data" {
                return """
    case \(statusCode.rawValue):
        completion(.\(swiftResult)(data))
    """
            } else {
                return """
case \(statusCode.rawValue):
    do {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom(dateDecodingStrategy)
        let result = try decoder.decode(\(responseType.modelNamed).self, from: data)

        completion(.\(swiftResult)(\(resultType("result", resultIsEnum))))
    } catch let error {
        interceptor?.networkFailedToParseObject(urlRequest: request, urlResponse: response, data: data, error: error)
        completion(.failure(.requestFailed(error: error)))
    }
"""
            }
        case .void(let statusCode, let resultIsEnum):
            if resultIsEnum {
                return """
case \(statusCode.rawValue):
    completion(.\(swiftResult)(\(resultType("", resultIsEnum))))
"""
            } else {
                return """
case \(statusCode.rawValue):
    completion(.\(swiftResult)(\(resultType("()", resultIsEnum))))
"""
            }
        case .int(let statusCode, _):
            return """
case \(statusCode.rawValue):
    if let stringValue = String(data: data, encoding: .utf8), let value = Int(stringValue) {
        completion(.success(value))
    } else {
        completion(.failure(.clientError(reason: "Failed to convert backend result to expected type"))
    }
"""
        case .double(let statusCode, _):
            return """
case \(statusCode.rawValue):
    if let stringValue = String(data: data, encoding: .utf8), let value = Double(stringValue) {
        completion(.success(value))
    } else {
        completion(.failure(.clientError(reason: "Failed to convert backend result to expected type"))
    }
"""
        case .float(let statusCode, _):
            return """
case \(statusCode.rawValue):
    if let stringValue = String(data: data, encoding: .utf8), let value = Float(stringValue) {
        completion(.success(value))
    } else {
        completion(.failure(.clientError(reason: "Failed to convert backend result to expected type"))
    }
"""
        case .boolean(let statusCode, _):
            return """
case \(statusCode.rawValue):
    if let stringValue = String(data: data, encoding: .utf8), let value = Bool(stringValue) {
        completion(.success(value))
    } else {
        completion(.failure(.clientError(reason: "Failed to convert backend result to expected type"))
    }
"""
        case .int64(let statusCode, _):
            return """
case \(statusCode.rawValue):
    if let stringValue = String(data: data, encoding: .utf8), let value = Int64(stringValue) {
        completion(.success(value))
    } else {
        completion(.failure(.clientError(reason: "Failed to convert backend result to expected type"))
    }
"""
        case .array(let statusCode, let resultIsEnum, let innerType):
            return """
case \(statusCode.rawValue):
    do {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom(dateDecodingStrategy)
        let result = try decoder.decode([\(innerType)].self, from: data)

        completion(.\(swiftResult)(\(resultType("result", resultIsEnum))))
    } catch let error {
        completion(.failure(.requestFailed(error: error)))
    }
"""
        case .enumeration(let statusCode, let resultIsEnum, let responseType):
            // This is necessary as iOS 12 doesnt support JSON fragments in JSONDecoder, so we have to do the parsing manually
            return """
            case \(statusCode.rawValue):
                if let stringValue = String(data: data, encoding: .utf8) {
                    // The string can be outputted as: "\\"enumValue\\"\\n", so we remove the newlines and remove the apostrophes
                    let cleanedStringValue = stringValue.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "\\""))
                    let enumValue = \(responseType)(rawValue: cleanedStringValue)
                    completion(.\(swiftResult)(\(resultType("enumValue", resultIsEnum))))
                } else {
                    completion(.failure(.clientError(reason: "Failed to convert backend result to expected type")))
                }
            """
        }
    }
}
