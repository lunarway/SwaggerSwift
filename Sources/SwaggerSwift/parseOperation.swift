import SwaggerSwiftML
import Foundation

struct QueryElement {
    let fieldName: String
    let fieldValue: String
    let isOptional: Bool
    let isEnum: Bool
}

func isErrorHttpCode(code: Int) -> Bool {
    return code < 199 || code > 299
}

func parse(operation: SwaggerSwiftML.Operation, httpMethod: HTTPMethod, servicePath: String, parameters: [Parameter], swagger: Swagger, swaggerFile: SwaggerFile, verbose: Bool) -> (NetworkRequestFunction, [ModelDefinition])? {
    if verbose {
        print("-> Creating function for request: \(httpMethod.rawValue.uppercased()) \(servicePath)", to: &stderr)
    }

    var functionName: String
    if let overrideName = operation.operationId {
        functionName = overrideName.lowercasingFirst
    } else {
        functionName = httpMethod.rawValue + servicePath
            .replacingOccurrences(of: "{", with: "")
            .replacingOccurrences(of: "}", with: "")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "-", with: "_")
            .split(separator: "_")
            .map { String($0).uppercasingFirst }
            .joined()

        functionName.unicodeScalars.removeAll(where: { !CharacterSet.alphanumerics.contains($0) })
    }

    let responseTypes: [(HTTPStatusCodes, TypeType, [ModelDefinition])] = operation.responses.compactMap {
        guard let requestResponse = $0.value else { return nil }

        let type = parse(request: requestResponse,
                         httpMethod: httpMethod,
                         servicePath: servicePath,
                         statusCode: $0.key,
                         swagger: swagger)

        let statusCode = HTTPStatusCodes(rawValue: $0.key)!
        return (statusCode, type.0, type.1)
    }

    let resTypes = responseTypes.map { ($0.0, $0.1) }

    var definitions = responseTypes.map { $0.2 }.flatMap { $0 }

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

                    if let format = format {
                        switch format {
                        case .int32:
                            return QueryElement(fieldName: $0.name, fieldValue: $0.name.camelized, isOptional: $0.required == false, isEnum: isEnum)
                        case .long:
                            return QueryElement(fieldName: $0.name, fieldValue: $0.name.camelized, isOptional: $0.required == false, isEnum: isEnum)
                        case .float:
                            return QueryElement(fieldName: $0.name, fieldValue: $0.name.camelized, isOptional: $0.required == false, isEnum: isEnum)
                        case .double:
                            return QueryElement(fieldName: $0.name, fieldValue: $0.name.camelized, isOptional: $0.required == false, isEnum: isEnum)
                        case .string:
                            return QueryElement(fieldName: $0.name, fieldValue: $0.name.camelized, isOptional: $0.required == false, isEnum: isEnum)
                        case .byte:
                            return QueryElement(fieldName: $0.name, fieldValue: $0.name.camelized, isOptional: $0.required == false, isEnum: isEnum)
                        case .binary:
                            return QueryElement(fieldName: $0.name, fieldValue: $0.name.camelized, isOptional: $0.required == false, isEnum: isEnum)
                        case .boolean:
                            return QueryElement(fieldName: $0.name, fieldValue: $0.name.camelized, isOptional: $0.required == false, isEnum: isEnum)
                        case .date:
                            return QueryElement(fieldName: $0.name, fieldValue: "ISO8601DateFormatter().string(from: \($0.name.camelized))", isOptional: $0.required == false, isEnum: isEnum)
                        case .dateTime:
                            return QueryElement(fieldName: $0.name, fieldValue: "ISO8601DateFormatter().string(from: \($0.name.camelized))", isOptional: $0.required == false, isEnum: isEnum)
                        case .password:
                            return QueryElement(fieldName: $0.name, fieldValue: $0.name.camelized, isOptional: $0.required == false, isEnum: isEnum)
                        case .email:
                            return QueryElement(fieldName: $0.name, fieldValue: $0.name.camelized, isOptional: $0.required == false, isEnum: isEnum)
                        case .unsupported:
                            return QueryElement(fieldName: $0.name, fieldValue: $0.name.camelized, isOptional: $0.required == false, isEnum: isEnum)
                        }
                    } else {
                        return QueryElement(fieldName: $0.name, fieldValue: $0.name.camelized, isOptional: $0.required == false, isEnum: isEnum)
                    }
                case .number(format: _, maximum: _, exclusiveMaximum: _, minimum: _, exclusiveMinimum: _, multipleOf: _):
                    return QueryElement(fieldName: $0.name, fieldValue: $0.name.camelized, isOptional: $0.required == false, isEnum: false)
                case .integer(format: _, maximum: _, exclusiveMaximum: _, minimum: _, exclusiveMinimum: _, multipleOf: _):
                    return QueryElement(fieldName: $0.name, fieldValue: $0.name.camelized, isOptional: $0.required == false, isEnum: false)
                case .boolean:
                    return QueryElement(fieldName: $0.name, fieldValue: $0.name.camelized, isOptional: $0.required == false, isEnum: false)
                case .array(_, collectionFormat: _, maxItems: _, minItems: _, uniqueItems: _):
                    return QueryElement(fieldName: $0.name, fieldValue: $0.name.camelized, isOptional: $0.required == false, isEnum: false)
                case .file:
                    return QueryElement(fieldName: $0.name, fieldValue: $0.name.camelized, isOptional: $0.required == false, isEnum: false)
                }
            case .header(type: _):
                return QueryElement(fieldName: $0.name, fieldValue: $0.name.camelized, isOptional: $0.required == false, isEnum: false)
            case .path(let type):
                switch type {
                case .string(format: _, enumValues: let enumValues, maxLength: _, minLength: _, pattern: _):
                    let isEnum = (enumValues?.count ?? 0) > 0
                    return QueryElement(fieldName: $0.name, fieldValue: $0.name.camelized, isOptional: $0.required == false, isEnum: isEnum)
                default:
                    return QueryElement(fieldName: $0.name, fieldValue: $0.name.camelized, isOptional: $0.required == false, isEnum: false)
                }
            case .formData(type: _, allowEmptyValue: _):
                return QueryElement(fieldName: $0.name, fieldValue: $0.name.camelized, isOptional: $0.required == false, isEnum: false)
            case .body(schema: _):
                return QueryElement(fieldName: $0.name, fieldValue: $0.name.camelized, isOptional: $0.required == false, isEnum: false)
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
            print("⚠️⚠️⚠️ Does not support consume type: \(consume) ⚠️⚠️⚠️")
            return nil
        }
    } else {
        print("⚠️⚠️⚠️ No provided consumer or not supported for function \(httpMethod.rawValue) \(servicePath), skipping ⚠️⚠️⚠️")
        return nil
    }

    let errorResponses = responseTypes.filter { !$0.0.isSuccess }
    let successResponses = responseTypes.filter { $0.0.isSuccess }

    let rt: [NetworkRequestFunctionResponseType] = responseTypes
        .sorted(by: { $0.0.rawValue < $1.0.rawValue })
        .map {
            let statusCode = $0.0
            let isSuccessResponse = $0.0.isSuccess ? successResponses.count > 1 : errorResponses.count > 1
            switch $0.1 {
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
                    return NetworkRequestFunctionResponseType.array($0.0, $0.0.isSuccess ? successResponses.count > 1 : errorResponses.count > 1, typeName)
                } else {
                    fatalError("Unsupported type inside array: \(type)")
                }
            case .object(typeName: let typeName):
                return NetworkRequestFunctionResponseType.object($0.0, $0.0.isSuccess ? successResponses.count > 1 : errorResponses.count > 1, typeName)
            case .void:
                return NetworkRequestFunctionResponseType.void($0.0, $0.0.isSuccess ? successResponses.count > 1 : errorResponses.count > 1)
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
