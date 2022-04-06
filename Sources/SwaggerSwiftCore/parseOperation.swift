import SwaggerSwiftML
import Foundation

struct QueryElement {
    enum ValueType {
        case date
        case `enum`
        case `default`
    }
    let fieldName: String
    let fieldValue: String
    let isOptional: Bool
    let valueType: ValueType
}

func isErrorHttpCode(code: Int) -> Bool {
    return code < 199 || code > 299
}

struct Response {
    let statusCode: HTTPStatusCodes
    let responseType: TypeType
    let embeddedDefinitions: [ModelDefinition]
}

func parse(operation: SwaggerSwiftML.Operation, httpMethod: HTTPMethod, servicePath: String, parameters: [Parameter], swagger: Swagger, swaggerFile: SwaggerFile) -> (NetworkRequestFunction, [ModelDefinition])? {
    log("-> Creating function for request: \(httpMethod.rawValue.uppercased()) \(servicePath)")

    var functionName: String
    if let overrideName = operation.operationId {
        functionName = overrideName.lowercasingFirst
    } else {
        functionName = httpMethod.rawValue + servicePath
            .replacingOccurrences(of: "{", with: "")
            .replacingOccurrences(of: "}", with: "")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "-", with: "_")
            .split(separator: "_")
            .map { String($0).uppercasingFirst }
            .joined()

        functionName.unicodeScalars.removeAll(where: { !CharacterSet.alphanumerics.contains($0) })
    }

    let responses: [Response] = operation.responses.compactMap {
        let statusCodeString = $0.key
        guard let statusCode = HTTPStatusCodes(rawValue: statusCodeString) else {
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

    let resTypes = responses.map { ($0.statusCode, $0.responseType) }

    var definitions = responses.map { $0.embeddedDefinitions }.flatMap { $0 }

    let operationParameters: [Parameter] = (operation.parameters ?? []).map {
        swagger.findParameter(node: $0)
    } + parameters

    let functionParametersResult = getFunctionParameters(operationParameters,
                                                         functionName: functionName,
                                                         isInternalOnly: operation.isInternalOnly,
                                                         responseTypes: resTypes,
                                                         swagger: swagger,
                                                         swaggerFile: swaggerFile)

    let functionParameters = functionParametersResult.0
    definitions.append(contentsOf: functionParametersResult.1)

    let queries: [QueryElement] = operationParameters.compactMap {
        if case ParameterLocation.query = $0.location {
            switch $0.location {
            case .query(let type, allowEmptyValue: _):
                switch type {
                case .string(format: let format, let enumValues, maxLength: _, minLength: _, pattern: _):
                    let isEnum = (enumValues?.count ?? 0) > 0
                    let valueType: QueryElement.ValueType = isEnum ? .enum : .default

                    if let format = format {
                        switch format {
                        case .int32:
                            return QueryElement(fieldName: $0.name, fieldValue: $0.name.camelized, isOptional: $0.required == false, valueType: valueType)
                        case .long:
                            return QueryElement(fieldName: $0.name, fieldValue: $0.name.camelized, isOptional: $0.required == false, valueType: valueType)
                        case .float:
                            return QueryElement(fieldName: $0.name, fieldValue: $0.name.camelized, isOptional: $0.required == false, valueType: valueType)
                        case .double:
                            return QueryElement(fieldName: $0.name, fieldValue: $0.name.camelized, isOptional: $0.required == false, valueType: valueType)
                        case .string:
                            return QueryElement(fieldName: $0.name, fieldValue: $0.name.camelized, isOptional: $0.required == false, valueType: valueType)
                        case .byte:
                            return QueryElement(fieldName: $0.name, fieldValue: $0.name.camelized, isOptional: $0.required == false, valueType: valueType)
                        case .binary:
                            return QueryElement(fieldName: $0.name, fieldValue: $0.name.camelized, isOptional: $0.required == false, valueType: valueType)
                        case .boolean:
                            return QueryElement(fieldName: $0.name, fieldValue: $0.name.camelized, isOptional: $0.required == false, valueType: valueType)
                        case .date:
                            return QueryElement(fieldName: $0.name, fieldValue: $0.name.camelized, isOptional: $0.required == false, valueType: .date)
                        case .dateTime:
                            return QueryElement(fieldName: $0.name, fieldValue: $0.name.camelized, isOptional: $0.required == false, valueType: .date)
                        case .password:
                            return QueryElement(fieldName: $0.name, fieldValue: $0.name.camelized, isOptional: $0.required == false, valueType: valueType)
                        case .email:
                            return QueryElement(fieldName: $0.name, fieldValue: $0.name.camelized, isOptional: $0.required == false, valueType: valueType)
                        case .unsupported:
                            return QueryElement(fieldName: $0.name, fieldValue: $0.name.camelized, isOptional: $0.required == false, valueType: valueType)
                        }
                    } else {
                        return QueryElement(fieldName: $0.name, fieldValue: $0.name.camelized, isOptional: $0.required == false, valueType: valueType)
                    }
                case .number(format: _, maximum: _, exclusiveMaximum: _, minimum: _, exclusiveMinimum: _, multipleOf: _):
                    return QueryElement(fieldName: $0.name, fieldValue: $0.name.camelized, isOptional: $0.required == false, valueType: .default)
                case .integer(format: _, maximum: _, exclusiveMaximum: _, minimum: _, exclusiveMinimum: _, multipleOf: _):
                    return QueryElement(fieldName: $0.name, fieldValue: $0.name.camelized, isOptional: $0.required == false, valueType: .default)
                case .boolean:
                    return QueryElement(fieldName: $0.name, fieldValue: $0.name.camelized, isOptional: $0.required == false, valueType: .default)
                case .array(_, collectionFormat: _, maxItems: _, minItems: _, uniqueItems: _):
                    return QueryElement(fieldName: $0.name, fieldValue: $0.name.camelized, isOptional: $0.required == false, valueType: .default)
                case .file:
                    return QueryElement(fieldName: $0.name, fieldValue: $0.name.camelized, isOptional: $0.required == false, valueType: .default)
                }
            case .header(type: _):
                return QueryElement(fieldName: $0.name, fieldValue: $0.name.camelized, isOptional: $0.required == false, valueType: .default)
            case .path(let type):
                switch type {
                case .string(format: _, enumValues: let enumValues, maxLength: _, minLength: _, pattern: _):
                    let valueType: QueryElement.ValueType = (enumValues?.count ?? 0) > 0 ? .enum : .default
                    return QueryElement(fieldName: $0.name, fieldValue: $0.name.camelized, isOptional: $0.required == false, valueType: valueType)
                default:
                    return QueryElement(fieldName: $0.name, fieldValue: $0.name.camelized, isOptional: $0.required == false, valueType: .default)
                }
            case .formData(type: _, allowEmptyValue: _):
                return QueryElement(fieldName: $0.name, fieldValue: $0.name.camelized, isOptional: $0.required == false, valueType: .default)
            case .body(schema: _):
                return QueryElement(fieldName: $0.name, fieldValue: $0.name.camelized, isOptional: $0.required == false, valueType: .default)
            }
        } else {
            return nil
        }
    }

    let headers: [NetworkRequestFunctionHeaderField] = operationParameters.compactMap {
        if case ParameterLocation.header = $0.location {
            return .init(headerName: $0.name, required: $0.required)
        } else {
            return nil
        }
    }

    let consumes: NetworkRequestFunctionConsumes
    if let consume = operation.consumes?.first ?? swagger.consumes?.first {
        switch consume {
        case "application/json":
            consumes = .json
        case "multipart/form-data":
            consumes = .multiPartFormData
        default:
            log("⚠️⚠️⚠️ Does not support consume type: \(consume) ⚠️⚠️⚠️")
            return nil
        }
    } else {
        log("⚠️⚠️⚠️ No provided consumer or not supported for function \(httpMethod.rawValue) \(servicePath), skipping ⚠️⚠️⚠️")
        return nil
    }

    let errorResponses = responses.filter { !$0.statusCode.isSuccess }
    let successResponses = responses.filter { $0.statusCode.isSuccess }

    let rt: [NetworkRequestFunctionResponseType] = responses
        .sorted(by: { $0.statusCode.rawValue < $1.statusCode.rawValue })
        .map {
            let statusCode = $0.statusCode
            let isSuccessResponse = $0.statusCode.isSuccess ? successResponses.count > 1 : errorResponses.count > 1
            switch $0.responseType {
            case .string:
                return NetworkRequestFunctionResponseType.textPlain(statusCode, isSuccessResponse)
            case .int:
                return NetworkRequestFunctionResponseType.int(statusCode, isSuccessResponse)
            case .double:
                return NetworkRequestFunctionResponseType.double(statusCode, isSuccessResponse)
            case .float:
                return NetworkRequestFunctionResponseType.float(statusCode, isSuccessResponse)
            case .boolean:
                return NetworkRequestFunctionResponseType.boolean(statusCode, isSuccessResponse)
            case .int64:
                return NetworkRequestFunctionResponseType.int64(statusCode, isSuccessResponse)
            case .array(let type):
                if case .object(let typeName) = type {
                    return NetworkRequestFunctionResponseType.array($0.statusCode, $0.statusCode.isSuccess ? successResponses.count > 1 : errorResponses.count > 1, typeName)
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

                return NetworkRequestFunctionResponseType.object($0.statusCode, $0.statusCode.isSuccess ? successResponses.count > 1 : errorResponses.count > 1, typeName)
            case .void:
                return NetworkRequestFunctionResponseType.void($0.statusCode, $0.statusCode.isSuccess ? successResponses.count > 1 : errorResponses.count > 1)
            case .date:
                fatalError("Not implemented")
            }
        }

    return (NetworkRequestFunction(description: operation.description,
                                   functionName: functionName,
                                   parameters: functionParameters,
                                   throws: false,
                                   consumes: consumes,
                                   isInternalOnly: operation.isInternalOnly,
                                   isDeprecated: operation.deprecated,
                                   httpMethod: httpMethod.rawValue.capitalized,
                                   servicePath: servicePath,
                                   queries: queries,
                                   headers: headers,
                                   responseTypes: rt),
            definitions)
}
