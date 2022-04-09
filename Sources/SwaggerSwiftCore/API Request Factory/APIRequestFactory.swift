import Foundation
import SwaggerSwiftML

struct APIRequestFactory {
    enum APIRequestFactoryError: Swift.Error {
        case unsupportedMimeType(String)
        case missingConsumeType
    }

    func generateRequest(for operation: SwaggerSwiftML.Operation, httpMethod: HTTPMethod, servicePath: String, swagger: Swagger, swaggerFile: SwaggerFile, parameters: [Parameter]) throws -> (APIRequest, [ModelDefinition]) {
        let functionName = resolveFunctionName(httpMethod: httpMethod.rawValue,
                                               servicePath: servicePath,
                                               operationId: operation.operationId)

        let responses: [Response] = operation.responses.compactMap {
            let statusCodeString = $0.key
            guard let statusCode = HTTPStatusCode(rawValue: statusCodeString) else {
                fatalError("Unknown status code received: \(statusCodeString)")
            }

            guard let requestResponse = $0.value else { return nil }

            let (responseType, embeddedDefinition) = parse(
                request: requestResponse,
                httpMethod: httpMethod,
                servicePath: servicePath,
                statusCode: statusCodeString,
                swagger: swagger
            )

            return .init(statusCode: statusCode,
                         responseType: responseType,
                         embeddedDefinitions: embeddedDefinition)
        }

        let responseMap: [ResponseTypeMap] = responses.map { ($0.statusCode, $0.responseType) }

        let (requestParameters, inlineModels) = resolveInputParameters(
            for: operation,
            functionName: functionName,
            responseTypes: responseMap,
            swagger: swagger,
            swaggerFile: swaggerFile
        )

        let operationParameters: [Parameter] = (operation.parameters ?? []).map {
            swagger.findParameter(node: $0)
        } + parameters

        let headers = operationParameters.compactMap { param -> APIRequestHeaderField? in
            if case ParameterLocation.header = param.location {
                return APIRequestHeaderField(headerName: param.name,
                                             isRequired: param.required)
            } else {
                return nil
            }
        }

        let apiRequest = APIRequest(
            description: operation.description,
            functionName: functionName,
            parameters: requestParameters,
            throws: false,
            consumes: try consumeMimeType(forOperation: operation, swagger: swagger),
            isInternalOnly: operation.isInternalOnly,
            isDeprecated: operation.deprecated,
            httpMethod: httpMethod,
            servicePath: servicePath,
            queries: resolveQueries(forOperation: operation, parameters: parameters, swagger: swagger),
            headers: headers,
            responseTypes: resolveResponseTypes(forOperation: operation, forHTTPMethod: httpMethod, at: servicePath, swagger: swagger)
        )

        return (apiRequest, inlineModels)
    }

    private func resolveResponseTypes(forOperation operation: SwaggerSwiftML.Operation, forHTTPMethod httpMethod: HTTPMethod, at servicePath: String, swagger: Swagger) -> [APIRequestResponseType] {
        let responses: [SwaggerSwiftCore.Response] = operation.responses.compactMap {
            let statusCodeString = $0.key
            guard let statusCode = HTTPStatusCode(rawValue: statusCodeString) else {
                fatalError("Unknown status code received: \(statusCodeString)")
            }
            guard let requestResponse = $0.value else { return nil }
            let (responseType, embeddedDefinition) = parse(
                request: requestResponse,
                httpMethod: httpMethod,
                servicePath: servicePath,
                statusCode: statusCodeString,
                swagger: swagger
            )
            return .init(statusCode: statusCode,
                         responseType: responseType,
                         embeddedDefinitions: embeddedDefinition)
        }

        let errorResponses = responses.filter { !$0.statusCode.isSuccess }
        let successResponses = responses.filter { $0.statusCode.isSuccess }

        return responses
            .sorted(by: { $0.statusCode.rawValue < $1.statusCode.rawValue })
            .map {
                let statusCode = $0.statusCode
                let isSuccessResponse = $0.statusCode.isSuccess ? successResponses.count > 1 : errorResponses.count > 1
                switch $0.responseType {
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
                        return APIRequestResponseType.array($0.statusCode, $0.statusCode.isSuccess ? successResponses.count > 1 : errorResponses.count > 1, typeName)
                    } else {
                        fatalError("Unsupported type inside array: \(type)")
                    }
                case .object(typeName: let typeName):
                    if let embeddedType = $0.embeddedDefinitions.first(where: { $0.typeName == typeName }) {
                        switch embeddedType {
                        case .enumeration:
                            return .enumeration($0.statusCode, $0.statusCode.isSuccess ? successResponses.count > 1 : errorResponses.count > 1, typeName)
                        default: break
                        }
                    }

                    return APIRequestResponseType.object($0.statusCode, $0.statusCode.isSuccess ? successResponses.count > 1 : errorResponses.count > 1, typeName)
                case .void:
                    return APIRequestResponseType.void($0.statusCode, $0.statusCode.isSuccess ? successResponses.count > 1 : errorResponses.count > 1)
                case .date:
                    fatalError("Not implemented")
                }
            }
    }

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

    private func consumeMimeType(forOperation operation: SwaggerSwiftML.Operation, swagger: Swagger) throws -> APIRequestConsumes {
        if let rawConsume = operation.consumes?.first ?? swagger.consumes?.first {
            if let consume = APIRequestConsumes(rawValue: rawConsume) {
                return consume
            } else {
                log("[\(swagger.serviceName)] ⚠️ SwaggerSwift does not support consume mime type '\(rawConsume)'")
                throw APIRequestFactoryError.unsupportedMimeType(rawConsume)
            }
        } else {
            throw APIRequestFactoryError.missingConsumeType
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

    /// Convert the Header name, e.g. `X-AppDeviceVersion` to the field name that is used on the object in the Swift code, e.g. `appDeviceVersion`
    /// - Parameter headerName:
    /// - Returns: the field name to use in the Swift struct
    func convertApiHeader(_ headerName: String) -> String {
        headerName.replacingOccurrences(of: "X-", with: "")
            .replacingOccurrences(of: "x-", with: "")
            .variableNameFormatted
    }
}
