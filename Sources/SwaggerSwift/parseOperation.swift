import SwaggerSwiftML

struct QueryElement {
    let fieldName: String
    let fieldValue: String
}

func isErrorHttpCode(code: Int) -> Bool {
    return code < 199 || code > 299
}

func parse(operation: SwaggerSwiftML.Operation, httpMethod: HTTPMethod, servicePath: String, parameters: [Parameter], swagger: Swagger, swaggerFile: SwaggerFile) -> (NetworkRequestFunction, [ModelDefinition]) {
    print("-> Creating function for request: \(httpMethod.rawValue.uppercased()) \(servicePath)")

    let functionName: String
    if let overrideName = operation.operationId {
        functionName = overrideName
    } else {
        functionName = httpMethod.rawValue + servicePath
            .replacingOccurrences(of: "{", with: "")
            .replacingOccurrences(of: "}", with: "")
            .replacingOccurrences(of: "/", with: "_")
            .split(separator: "_")
            .map { String($0).uppercasingFirst }
            .joined()
    }

    let responseTypes: [(HTTPStatusCodes, TypeType, [ModelDefinition])] = operation.responses.map {
        let type = parse(request: $0.value, httpMethod: httpMethod, servicePath: servicePath, statusCode: $0.key, swagger: swagger)
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
            case .query(type: let type, allowEmptyValue: _):
                switch type {
                case .string(format: let format, enumValues: _, maxLength: _, minLength: _, pattern: _):
                    if let format = format {
                        switch format {
                        case .int32:
                            return QueryElement(fieldName: $0.name, fieldValue: $0.name)
                        case .long:
                            return QueryElement(fieldName: $0.name, fieldValue: $0.name)
                        case .float:
                            return QueryElement(fieldName: $0.name, fieldValue: $0.name)
                        case .double:
                            return QueryElement(fieldName: $0.name, fieldValue: $0.name)
                        case .string:
                            return QueryElement(fieldName: $0.name, fieldValue: $0.name)
                        case .byte:
                            return QueryElement(fieldName: $0.name, fieldValue: $0.name)
                        case .binary:
                            return QueryElement(fieldName: $0.name, fieldValue: $0.name)
                        case .boolean:
                            return QueryElement(fieldName: $0.name, fieldValue: $0.name)
                        case .date:
                            return QueryElement(fieldName: $0.name, fieldValue: "ISO8601DateFormatter().string(from: \($0.name))")
                        case .dateTime:
                            return QueryElement(fieldName: $0.name, fieldValue: "ISO8601DateFormatter().string(from: \($0.name))")
                        case .password:
                            return QueryElement(fieldName: $0.name, fieldValue: $0.name)
                        case .email:
                            return QueryElement(fieldName: $0.name, fieldValue: $0.name)
                        case .unsupported(_):
                            return QueryElement(fieldName: $0.name, fieldValue: $0.name)
                        }
                    }
                case .number(format: _, maximum: _, exclusiveMaximum: _, minimum: _, exclusiveMinimum: _, multipleOf: _):
                    return QueryElement(fieldName: $0.name, fieldValue: $0.name)
                case .integer(format: _, maximum: _, exclusiveMaximum: _, minimum: _, exclusiveMinimum: _, multipleOf: _):
                    return QueryElement(fieldName: $0.name, fieldValue: $0.name)
                case .boolean:
                    return QueryElement(fieldName: $0.name, fieldValue: $0.name)
                case .array(_, collectionFormat: _, maxItems: _, minItems: _, uniqueItems: _):
                    return QueryElement(fieldName: $0.name, fieldValue: $0.name)
                case .file:
                    return QueryElement(fieldName: $0.name, fieldValue: $0.name)
                }
            case .header(type: _):
                return QueryElement(fieldName: $0.name, fieldValue: $0.name)
            case .path(type: _):
                return QueryElement(fieldName: $0.name, fieldValue: $0.name)
            case .formData(type: _, allowEmptyValue: _):
                return QueryElement(fieldName: $0.name, fieldValue: $0.name)
            case .body(schema: _):
                return QueryElement(fieldName: $0.name, fieldValue: $0.name)
            }
        } else {
            return nil
        }

        return QueryElement(fieldName: $0.name, fieldValue: $0.name)
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
            fatalError("[ERROR] Does not support consume type: \(consume)")
        }
    } else {
        fatalError("[ERROR] No provided consumer for function \(httpMethod.rawValue) \(servicePath)")
    }


    let errorResponses = responseTypes.filter { !$0.0.isSuccess }
    let successResponses = responseTypes.filter { $0.0.isSuccess }

    let rt: [NetworkRequestFunctionResponseType] = responseTypes
        .sorted(by: { $0.0.rawValue < $1.0.rawValue })
        .map {
            switch $0.1 {
            case .string:
                return NetworkRequestFunctionResponseType.textPlain($0.0, $0.0.isSuccess ? successResponses.count > 1 : errorResponses.count > 1)
            case .int, .double, .float, .boolean, .int64, .array:
                fatalError("not supported")
            case .object(typeName: let typeName):
                return NetworkRequestFunctionResponseType.applicationJson($0.0, $0.0.isSuccess ? successResponses.count > 1 : errorResponses.count > 1, typeName)
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
                                   returnType: "URLSessionDataTask",
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
