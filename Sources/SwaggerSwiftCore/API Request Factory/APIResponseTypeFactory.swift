import SwaggerSwiftML

/// Creates response types for a given API request
public struct APIResponseTypeFactory {
    public init() {}

    /// Get a list of all the responses for an API request
    /// - Parameters:
    ///   - operation: the Swagger operation - This is the actual API request data.
    ///   - httpMethod: the HTTP method for the request
    ///   - servicePath: the service path to the request, e.g. `/ping/pong`
    ///   - swagger: the full swagger spec
    /// - Returns: all response types for a given API request
    func make(
        forResponses responses: [Response],
        forHTTPMethod httpMethod: HTTPMethod,
        at servicePath: String,
        swagger: Swagger
    ) -> [APIRequestResponseType] {
        let errorResponses = responses.filter { !$0.statusCode.isSuccess }
        let successResponses = responses.filter { $0.statusCode.isSuccess }

        let responsesTypes =
            responses
            .sorted(by: { $0.statusCode.rawValue < $1.statusCode.rawValue })
            .compactMap { response -> APIRequestResponseType? in
                let statusCode = response.statusCode
                let isSuccessResponse =
                    response.statusCode.isSuccess ? successResponses.count > 1 : errorResponses.count > 1

                switch response.responseType {
                case .string:
                    return APIRequestResponseType.textPlain(statusCode, isSuccessResponse)
                case .int:
                    return APIRequestResponseType.int(statusCode, isSuccessResponse)
                case .double:
                    return APIRequestResponseType.double(statusCode, isSuccessResponse)
                case .float:
                    return APIRequestResponseType.float(statusCode, isSuccessResponse)
                case .boolean:
                    return APIRequestResponseType.boolean(statusCode, isSuccessResponse)
                case .int64:
                    return APIRequestResponseType.int64(statusCode, isSuccessResponse)
                case .array(let type):
                    if case .object(let typeName) = type {
                        return APIRequestResponseType.array(
                            response.statusCode,
                            response.statusCode.isSuccess ? successResponses.count > 1 : errorResponses.count > 1,
                            typeName: typeName
                        )
                    } else {
                        log(
                            "[\(swagger.serviceName) - \(httpMethod.rawValue) \(servicePath)] Unsupported type '\(type)' in array]"
                        )
                        return nil
                    }
                case .object(let typeName):
                    if let embeddedType = response.inlineModels.first(where: { $0.typeName == typeName }) {
                        switch embeddedType {
                        case .enumeration:
                            return .enumeration(
                                response.statusCode,
                                response.statusCode.isSuccess
                                    ? successResponses.count > 1 : errorResponses.count > 1,
                                typeName: typeName
                            )
                        default: break
                        }
                    }

                    return APIRequestResponseType.object(
                        response.statusCode,
                        response.statusCode.isSuccess ? successResponses.count > 1 : errorResponses.count > 1,
                        typeName: typeName
                    )
                case .enumeration(let typeName):
                    return .enumeration(
                        response.statusCode,
                        response.statusCode.isSuccess ? successResponses.count > 1 : errorResponses.count > 1,
                        typeName: typeName
                    )
                case .void:
                    return APIRequestResponseType.void(
                        response.statusCode,
                        response.statusCode.isSuccess ? successResponses.count > 1 : errorResponses.count > 1
                    )
                case .date:
                    log(
                        "[\(swagger.serviceName) - \(httpMethod.rawValue) \(servicePath)] Unsupported date type in response]"
                    )
                    return nil
                case .typeAlias(let typeName, _):
                    return APIRequestResponseType.object(statusCode, isSuccessResponse, typeName: typeName)
                }
            }

        return responsesTypes
    }
}
