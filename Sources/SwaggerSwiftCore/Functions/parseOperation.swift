//import SwaggerSwiftML
//import Foundation
//
//struct Response {
//    let statusCode: HTTPStatusCode
//    let responseType: TypeType
//    let embeddedDefinitions: [ModelDefinition]
//}
//
//func parse(operation: SwaggerSwiftML.Operation, httpMethod: HTTPMethod, servicePath: String, parameters: [Parameter], swagger: Swagger, swaggerFile: SwaggerFile) -> (APIRequest, [ModelDefinition])? {
//    log("-> Creating function for request: \(httpMethod.rawValue.uppercased()) \(servicePath)")
//
//    let responses: [Response] = operation.responses.compactMap {
//        let statusCodeString = $0.key
//        guard let statusCode = HTTPStatusCode(rawValue: statusCodeString) else {
//            fatalError("Unknown status code received: \(statusCodeString)")
//        }
//
//        guard let requestResponse = $0.value else { return nil }
//
//        let (responseType, embeddedDefinition) = parse(
//            request: requestResponse,
//            httpMethod: httpMethod,
//            servicePath: servicePath,
//            statusCode: statusCodeString,
//            swagger: swagger
//        )
//
//        return .init(statusCode: statusCode,
//                     responseType: responseType,
//                     embeddedDefinitions: embeddedDefinition)
//    }
//
//    let resTypes = responses.map { ($0.statusCode, $0.responseType) }
//
//    var definitions = responses.map { $0.embeddedDefinitions }.flatMap { $0 }
//
//    let operationParameters: [Parameter] = (operation.parameters ?? []).map {
//        swagger.findParameter(node: $0)
//    } + parameters
//
//    let functionParametersResult = resolveInputHeadersToApi(operationParameters,
//                                                            functionName: functionName,
//                                                            isInternalOnly: operation.isInternalOnly,
//                                                            responseTypes: resTypes,
//                                                            swagger: swagger,
//                                                            swaggerFile: swaggerFile)
//
//    let functionParameters = functionParametersResult.0
//    definitions.append(contentsOf: functionParametersResult.1)
//
//    let queries: [QueryElement] = operationParameters.compactMap {
//        guard case ParameterLocation.query = $0.location else {
//            return nil
//        }
//
//        switch $0.location {
//        case .query(let type, _):
//            switch type {
//            case .string(let format, let enumValues, _, _, _):
//                let isEnum = (enumValues?.count ?? 0) > 0
//                let valueType: QueryElement.ValueType = isEnum ? .enum : .default
//
//                if let format = format {
//                    switch format {
//                    case .int32: fallthrough
//                    case .long: fallthrough
//                    case .float: fallthrough
//                    case .double: fallthrough
//                    case .string: fallthrough
//                    case .byte: fallthrough
//                    case .binary: fallthrough
//                    case .boolean: fallthrough
//                    case .password: fallthrough
//                    case .email: fallthrough
//                    case .unsupported:
//                        return QueryElement(
//                            fieldName: $0.name,
//                            fieldValue: $0.name.camelized,
//                            isOptional: $0.required == false,
//                            valueType: valueType
//                        )
//                    case .date: fallthrough
//                    case .dateTime:
//                        return QueryElement(
//                            fieldName: $0.name,
//                            fieldValue: $0.name.camelized,
//                            isOptional: $0.required == false,
//                            valueType: .date
//                        )
//                    }
//                } else {
//                    return QueryElement(
//                        fieldName: $0.name,
//                        fieldValue: $0.name.camelized,
//                        isOptional: $0.required == false,
//                        valueType: valueType
//                    )
//                }
//            case .number: fallthrough
//            case .integer: fallthrough
//            case .boolean: fallthrough
//            case .array: fallthrough
//            case .file:
//                return QueryElement(
//                    fieldName: $0.name,
//                    fieldValue: $0.name.camelized,
//                    isOptional: $0.required == false,
//                    valueType: .default
//                )
//            }
//        case .header:
//            return QueryElement(
//                fieldName: $0.name,
//                fieldValue: $0.name.camelized,
//                isOptional: $0.required == false,
//                valueType: .default
//            )
//        case .path(let type):
//            switch type {
//            case .string(_, let enumValues, _, _, _):
//                let valueType: QueryElement.ValueType = (enumValues?.count ?? 0) > 0 ? .enum : .default
//                return QueryElement(
//                    fieldName: $0.name,
//                    fieldValue: $0.name.camelized,
//                    isOptional: $0.required == false,
//                    valueType: valueType
//                )
//            default:
//                return QueryElement(
//                    fieldName: $0.name,
//                    fieldValue: $0.name.camelized,
//                    isOptional: $0.required == false,
//                    valueType: .default
//                )
//            }
//        case .formData:
//            return QueryElement(
//                fieldName: $0.name,
//                fieldValue: $0.name.camelized,
//                isOptional: $0.required == false,
//                valueType: .default
//            )
//        case .body:
//            return QueryElement(
//                fieldName: $0.name,
//                fieldValue: $0.name.camelized,
//                isOptional: $0.required == false,
//                valueType: .default
//            )
//        }
//    }
//
//    let headers: [APIRequestHeaderField] = operationParameters.compactMap {
//        if case ParameterLocation.header = $0.location {
//            return .init(headerName: $0.name, isRequired: $0.required)
//        } else {
//            return nil
//        }
//    }
//
//    let consumes: APIRequestConsumes
//    if let consume = operation.consumes?.first ?? swagger.consumes?.first {
//        switch consume {
//        case "application/json":
//            consumes = .json
//        case "multipart/form-data":
//            consumes = .multiPartFormData
//        default:
//            log("⚠️⚠️⚠️ Does not support consume type: \(consume) ⚠️⚠️⚠️")
//            return nil
//        }
//    } else {
//        log("⚠️⚠️⚠️ No provided consumer or not supported for function \(httpMethod.rawValue) \(servicePath), skipping ⚠️⚠️⚠️")
//        return nil
//    }
//
//    let errorResponses = responses.filter { !$0.statusCode.isSuccess }
//    let successResponses = responses.filter { $0.statusCode.isSuccess }
//
//    let rt: [APIRequestResponseType] = responses
//        .sorted(by: { $0.statusCode.rawValue < $1.statusCode.rawValue })
//        .map {
//            let statusCode = $0.statusCode
//            let isSuccessResponse = $0.statusCode.isSuccess ? successResponses.count > 1 : errorResponses.count > 1
//            switch $0.responseType {
//            case .string:
//                return APIRequestResponseType.textPlain(statusCode, isSuccessResponse)
//            case .int:
//                return APIRequestResponseType.int(statusCode, isSuccessResponse)
//            case .double:
//                return APIRequestResponseType.double(statusCode, isSuccessResponse)
//            case .float:
//                return APIRequestResponseType.float(statusCode, isSuccessResponse)
//            case .boolean:
//                return APIRequestResponseType.boolean(statusCode, isSuccessResponse)
//            case .int64:
//                return APIRequestResponseType.int64(statusCode, isSuccessResponse)
//            case .array(let type):
//                if case .object(let typeName) = type {
//                    return APIRequestResponseType.array($0.statusCode, $0.statusCode.isSuccess ? successResponses.count > 1 : errorResponses.count > 1, typeName)
//                } else {
//                    fatalError("Unsupported type inside array: \(type)")
//                }
//            case .object(typeName: let typeName):
//                if let embeddedType = $0.embeddedDefinitions.first(where: { $0.typeName == typeName }) {
//                    switch embeddedType {
//                    case .enumeration:
//                        return .enumeration($0.statusCode, $0.statusCode.isSuccess ? successResponses.count > 1 : errorResponses.count > 1, typeName)
//                    default: break
//                    }
//                }
//
//                return APIRequestResponseType.object($0.statusCode, $0.statusCode.isSuccess ? successResponses.count > 1 : errorResponses.count > 1, typeName)
//            case .void:
//                return APIRequestResponseType.void($0.statusCode, $0.statusCode.isSuccess ? successResponses.count > 1 : errorResponses.count > 1)
//            case .date:
//                fatalError("Not implemented")
//            }
//        }
//
//    let functionName = resolveFunctionName(httpMethod: httpMethod.rawValue,
//                                           servicePath: servicePath,
//                                           operationId: operation.operationId)
//
//    return (APIRequest(description: operation.description,
//                       functionName: functionName,
//                       parameters: functionParameters,
//                       throws: false,
//                       consumes: consumes,
//                       isInternalOnly: operation.isInternalOnly,
//                       isDeprecated: operation.deprecated,
//                       httpMethod: httpMethod.rawValue.capitalized,
//                       servicePath: servicePath,
//                       queries: queries,
//                       headers: headers,
//                       responseTypes: rt),
//            definitions)
//}
