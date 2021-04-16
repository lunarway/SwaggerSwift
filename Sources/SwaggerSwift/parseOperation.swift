import SwaggerSwiftML

struct QueryElement {
    let fieldName: String
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

    let functionParametersResult = getFunctionParameters(operationParameters, functionName: functionName, responseTypes: resTypes, swagger: swagger, swaggerFile: swaggerFile)
    let functionParameters = functionParametersResult.0
    definitions.append(contentsOf: functionParametersResult.1)

    let queries: [QueryElement] = operationParameters.compactMap {
        if case ParameterLocation.query = $0.location {
            return QueryElement(fieldName: $0.name)
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
                                   httpMethod: httpMethod.rawValue.capitalized,
                                   servicePath: servicePath,
                                   queries: queries,
                                   headers: headers,
                                   responseTypes: rt),
            definitions)
}
