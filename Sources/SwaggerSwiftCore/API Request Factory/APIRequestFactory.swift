import Foundation
import SwaggerSwiftML

public struct APIRequestFactory {
    let apiResponseTypeFactory: APIResponseTypeFactory
    let requestParameterFactory: RequestParameterFactory
    let modelTypeResolver: ModelTypeResolver

    public init(apiResponseTypeFactory: APIResponseTypeFactory, requestParameterFactory: RequestParameterFactory, modelTypeResolver: ModelTypeResolver) {
        self.apiResponseTypeFactory = apiResponseTypeFactory
        self.requestParameterFactory = requestParameterFactory
        self.modelTypeResolver = modelTypeResolver
    }

    public enum APIRequestFactoryError: Swift.Error {
        case unsupportedMimeType(httpMethod: String, servicePath: String, mimeType: String)
        case missingConsumeType(httpMethod: String, servicePath: String)
    }

    func generateRequest(for operation: SwaggerSwiftML.Operation, httpMethod: HTTPMethod, servicePath: String, swagger: Swagger, swaggerFile: SwaggerFile, pathParameters: [Parameter]) throws -> (APIRequest, [ModelDefinition]) {
        let functionName = resolveFunctionName(httpMethod: httpMethod.rawValue,
                                               servicePath: servicePath,
                                               operationId: operation.operationId)

        var inlineResponseModels = [ModelDefinition]()

        let responses: [Response] = operation.responses.compactMap {
            let statusCodeString = $0.key
            guard let statusCode = HTTPStatusCode(rawValue: statusCodeString) else {
                fatalError("Unknown status code received: \(statusCodeString)")
            }

            guard let requestResponse = $0.value else { return nil }

            if let (responseType, embeddedDefinitions) = parse(request: requestResponse,
                                                               httpMethod: httpMethod,
                                                               servicePath: servicePath,
                                                               statusCode: statusCodeString,
                                                               swagger: swagger,
                                                               modelTypeResolver: modelTypeResolver) {
                return .init(statusCode: statusCode,
                             responseType: responseType,
                             inlineModels: embeddedDefinitions)
            } else {
                return nil
            }
        }

        let responseInlineModels = responses.flatMap { $0.inlineModels }
        inlineResponseModels.append(contentsOf: responseInlineModels)

        let responseMap: [ResponseTypeMap] = responses.map { ($0.statusCode, $0.responseType) }

        let (functionParameters, inlineModels) = requestParameterFactory.make(
            forOperation: operation,
            functionName: functionName,
            responseTypes: responseMap,
            pathParameters: pathParameters,
            swagger: swagger,
            swaggerFile: swaggerFile
        )

        inlineResponseModels.append(contentsOf: inlineModels)

        let allParameters: [Parameter] = (operation.parameters ?? []).map {
            swagger.findParameter(node: $0)
        } + pathParameters

        let headers = allParameters.compactMap { param -> APIRequestHeaderField? in
            if case ParameterLocation.header = param.location {
                return APIRequestHeaderField(headerName: param.name,
                                             isRequired: param.required)
            } else {
                return nil
            }
        }

        let queryItems = resolveQueries(forOperation: operation, parameters: allParameters, swagger: swagger)

        let apiResponseTypes = apiResponseTypeFactory.make(forResponses: responses,
                                                           forHTTPMethod: httpMethod,
                                                           at: servicePath,
                                                           swagger: swagger)

        inlineResponseModels.append(contentsOf: inlineModels)

        let apiRequest = APIRequest(
            description: operation.description,
            functionName: functionName,
            parameters: functionParameters,
            throws: false,
            consumes: try consumeMimeType(forOperation: operation, swagger: swagger, httpMethod: httpMethod.rawValue, servicePath: servicePath),
            isInternalOnly: operation.isInternalOnly,
            isDeprecated: operation.deprecated,
            httpMethod: httpMethod,
            servicePath: servicePath,
            queries: queryItems,
            headers: headers,
            responseTypes: apiResponseTypes
        )

        return (apiRequest, inlineResponseModels)
    }

    /// Create the list of URLQueryItem assignments that needs to be performed in the body of the request. This is not to
    /// be confused with the function parameters, which only represent the input of the function from all places, e.g. query,
    /// path, body, and so on.
    /// - Parameters:
    ///   - operation: the swagger operation
    ///   - parameters: the total set of parameters available to the api request
    ///   - swagger: the swagger spec
    /// - Returns: the list of query elements that should be set in the request
    private func resolveQueries(forOperation operation: SwaggerSwiftML.Operation, parameters: [Parameter], swagger: Swagger) -> [QueryElement] {
        let operationParameters: [Parameter] = (operation.parameters ?? []).map {
            swagger.findParameter(node: $0)
        } + parameters

        let queries: [QueryElement] = operationParameters.compactMap {
            guard case ParameterLocation.query = $0.location else {
                return nil
            }

            switch $0.location {
            case .query(let type, _):
                switch type {
                case .string(let format, let enumValues, _, _, _):
                    let isEnum = (enumValues?.count ?? 0) > 0
                    let valueType: QueryElement.ValueType = isEnum ? .enum : .default

                    if let format = format {
                        switch format {
                        case .int32: fallthrough
                        case .long: fallthrough
                        case .float: fallthrough
                        case .double: fallthrough
                        case .string: fallthrough
                        case .byte: fallthrough
                        case .binary: fallthrough
                        case .boolean: fallthrough
                        case .password: fallthrough
                        case .email: fallthrough
                        case .unsupported:
                            return QueryElement(
                                fieldName: $0.name,
                                fieldValue: $0.name.camelized,
                                isOptional: $0.required == false,
                                valueType: valueType
                            )
                        case .date: fallthrough
                        case .dateTime:
                            return QueryElement(
                                fieldName: $0.name,
                                fieldValue: $0.name.camelized,
                                isOptional: $0.required == false,
                                valueType: .date
                            )
                        }
                    } else {
                        return QueryElement(
                            fieldName: $0.name,
                            fieldValue: $0.name.camelized,
                            isOptional: $0.required == false,
                            valueType: valueType
                        )
                    }
                case .number: fallthrough
                case .integer: fallthrough
                case .boolean: fallthrough
                case .array: fallthrough
                case .file:
                    return QueryElement(
                        fieldName: $0.name,
                        fieldValue: $0.name.camelized,
                        isOptional: $0.required == false,
                        valueType: .default
                    )
                }
            case .header:
                return QueryElement(
                    fieldName: $0.name,
                    fieldValue: $0.name.camelized,
                    isOptional: $0.required == false,
                    valueType: .default
                )
            case .path(let type):
                switch type {
                case .string(_, let enumValues, _, _, _):
                    let valueType: QueryElement.ValueType = (enumValues?.count ?? 0) > 0 ? .enum : .default
                    return QueryElement(
                        fieldName: $0.name,
                        fieldValue: $0.name.camelized,
                        isOptional: $0.required == false,
                        valueType: valueType
                    )
                default:
                    return QueryElement(
                        fieldName: $0.name,
                        fieldValue: $0.name.camelized,
                        isOptional: $0.required == false,
                        valueType: .default
                    )
                }
            case .formData:
                return QueryElement(
                    fieldName: $0.name,
                    fieldValue: $0.name.camelized,
                    isOptional: $0.required == false,
                    valueType: .default
                )
            case .body:
                return QueryElement(
                    fieldName: $0.name,
                    fieldValue: $0.name.camelized,
                    isOptional: $0.required == false,
                    valueType: .default
                )
            }
        }

        return queries
    }

    private func consumeMimeType(forOperation operation: SwaggerSwiftML.Operation, swagger: Swagger, httpMethod: String, servicePath: String) throws -> APIRequestConsumes {
        if let rawConsume = operation.consumes?.first ?? swagger.consumes?.first {
            if let consume = APIRequestConsumes(rawValue: rawConsume) {
                return consume
            } else {
                log("[\(swagger.serviceName) \(httpMethod) \(servicePath)] ⚠️ SwaggerSwift does not support consume mime type '\(rawConsume)'")
                throw APIRequestFactoryError.unsupportedMimeType(httpMethod: httpMethod, servicePath: servicePath, mimeType: rawConsume)
            }
        } else {
            throw APIRequestFactoryError.missingConsumeType(httpMethod: httpMethod, servicePath: servicePath)
        }
    }

    private func resolveFunctionName(httpMethod: String, servicePath: String, operationId: String?) -> String {
        var functionName: String
        if let overrideName = operationId {
            functionName = overrideName.lowercasingFirst
        } else {
            functionName = httpMethod + servicePath
                .replacingOccurrences(of: "{", with: "")
                .replacingOccurrences(of: "}", with: "")
                .replacingOccurrences(of: "/", with: "_")
                .replacingOccurrences(of: "-", with: "_")
                .split(separator: "_")
                .map { String($0).uppercasingFirst }
                .joined()

        }

        functionName.unicodeScalars.removeAll(where: { !CharacterSet.alphanumerics.contains($0) })

        return functionName
    }
}

/// Convert the Header name, e.g. `X-AppDeviceVersion` to the field name that is used on the object in the Swift code, e.g. `appDeviceVersion`
/// - Parameter headerName:
/// - Returns: the field name to use in the Swift struct
func convertApiHeader(_ headerName: String) -> String {
    headerName.replacingOccurrences(of: "X-", with: "")
        .replacingOccurrences(of: "x-", with: "")
        .variableNameFormatted
}
