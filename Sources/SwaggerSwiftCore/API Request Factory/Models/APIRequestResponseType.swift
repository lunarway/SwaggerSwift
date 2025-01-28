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

  func print(apiName: String, errorType: String) -> String {
    let failed = !statusCode.isSuccess

    let resultType: (String, Bool) -> String = { resultType, enumBased -> String in
      let resultBlock = resultType.count == 0 ? "" : "(\(resultType))"
      if failed {
        if enumBased {
          return "\(errorType).backendError(error: .\(statusCode.name)\(resultBlock))"
        } else {
          return "\(errorType).backendError(error: \(resultType))"
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
            \(failed ? "throw" : "return") \(resultType("result", resultIsEnum))
        """
    case .object(let statusCode, let resultIsEnum, let responseType):
      if responseType == "Data" {
        return """
          case \(statusCode.rawValue):
              \(failed ? "throw" : "return") data
          """
      } else {
        return """
          case \(statusCode.rawValue):
              let result: \(responseType.modelNamed)
              do {
                  result = try decoder.decode(\(responseType.modelNamed).self, from: data)
              } catch let error {
                  interceptor?.networkFailedToParseObject(
                      urlRequest: request,
                      urlResponse: response,
                      data: data,
                      error: error
                  )
                  throw \(errorType).requestFailed(error: error)
              }
                  \(failed ? "throw" : "return") \(resultType("result", resultIsEnum))
          """
      }
    case .void(let statusCode, let resultIsEnum):
      if resultIsEnum {
        return """
          case \(statusCode.rawValue):
              \(failed ? "throw" : "return") \(resultType("", resultIsEnum))
          """
      } else {
        return """
          case \(statusCode.rawValue):
              \(failed ? "throw" : "return") \(resultType("()", resultIsEnum))
          """
      }
    case .int(let statusCode, _):
      return """
        case \(statusCode.rawValue):
            if let stringValue = String(data: data, encoding: .utf8), let value = Int(stringValue) {
                return .success(value)
            } else {
                let error = NSError(domain: "\(apiName)",
                                    code: 0,
                                    userInfo: [
                                        NSLocalizedDescriptionKey: "Failed to convert backend result to expected type"
                                    ]
                )

                throw \(errorType).requestFailed(error: error)
            }
        """
    case .double(let statusCode, _):
      return """
        case \(statusCode.rawValue):
            if let stringValue = String(data: data, encoding: .utf8), let value = Double(stringValue) {
                return value
            } else {
                let error = NSError(domain: "\(apiName)",
                                    code: 0,
                                    userInfo: [
                                        NSLocalizedDescriptionKey: "Failed to convert backend result to expected type"
                                    ]
                )

                throw \(errorType).requestFailed(error: error)
            }
        """
    case .float(let statusCode, _):
      return """
        case \(statusCode.rawValue):
            if let stringValue = String(data: data, encoding: .utf8), let value = Float(stringValue) {
                return value
            } else {
                let error = NSError(domain: "\(apiName)",
                                    code: 0,
                                    userInfo: [
                                        NSLocalizedDescriptionKey: "Failed to convert backend result to expected type"
                                    ]
                )

                throw \(errorType).requestFailed(error: error)
            }
        """
    case .boolean(let statusCode, _):
      return """
        case \(statusCode.rawValue):
            if let stringValue = String(data: data, encoding: .utf8), let value = Bool(stringValue) {
                return value
            } else {
                let error = NSError(domain: "\(apiName)",
                                    code: 0,
                                    userInfo: [
                                        NSLocalizedDescriptionKey: "Failed to convert backend result to expected type"
                                    ]
                )

                throw \(errorType).requestFailed(error: error)
            }
        """
    case .int64(let statusCode, _):
      return """
        case \(statusCode.rawValue):
            if let stringValue = String(data: data, encoding: .utf8), let value = Int64(stringValue) {
                return value
            } else {
                let error = NSError(domain: "\(apiName)",
                                    code: 0,
                                    userInfo: [
                                        NSLocalizedDescriptionKey: "Failed to convert backend result to expected type"
                                    ]
                )

                throw \(errorType).requestFailed(error: error)
            }
        """
    case .array(let statusCode, let resultIsEnum, let innerType):
      return """
        case \(statusCode.rawValue):
            let result: [\(innerType)]
            do {
                result = try decoder.decode([\(innerType)].self, from: data)
            } catch let error {
                throw \(errorType).requestFailed(error: error))
            }
            \(failed ? "throw" : "return") \(resultType("result", resultIsEnum))
        """
    case .enumeration(let statusCode, let resultIsEnum, let responseType):
      // This is necessary as iOS 12 doesnt support JSON fragments in JSONDecoder,
      // so we have to do the parsing manually
      return """
        case \(statusCode.rawValue):
            if let stringValue = String(data: data, encoding: .utf8) {
                // The string can be outputted as: "\\"enumValue\\"\\n", so we remove the newlines and remove the apostrophes
                let cleanedStringValue = stringValue
                    .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                    .trimmingCharacters(in: CharacterSet(charactersIn: "\\""))

                let enumValue = \(responseType)(rawValue: cleanedStringValue)
                \(failed ? "throw" : "return") \(resultType("enumValue", resultIsEnum))
            } else {
                let error = NSError(domain: "\(apiName)",
                                    code: 0,
                                    userInfo: [
                                        NSLocalizedDescriptionKey: "Failed to convert backend result to expected type"
                                    ]
                )

                throw \(errorType).requestFailed(error: error)
            }
        """
    }
  }
}
