import SwaggerSwiftML

func getFunctionParameters(_ parameters: [Parameter], functionName: String, responseTypes: [(HTTPStatusCodes, TypeType)], swagger: Swagger) -> ([FunctionParameter], [ModelDefinition]) {
    var resolvedParameters = [FunctionParameter]()
    var resolvedModelDefinitions = [ModelDefinition]()
    let typeName = functionName.components(separatedBy: "_").map { $0.capitalizingFirstLetter() }.joined(separator: "")

    // Headers

    let headers: [(Parameter, ParameterType)] = parameters.compactMap {
        if case ParameterLocation.header(let type) = $0.location {
            return ($0, type)
        } else {
            return nil
        }
    }

    if headers.count > 0 {
        let typeName = "\(typeName)Headers"
        let model = Model(serviceName: swagger.serviceName, description: "A collection of the header fields required for the request", typeName: typeName, fields: headers.map { param, type in
            let result = type.toType(typePrefix: typeName, swagger: swagger)
            resolvedModelDefinitions.append(contentsOf: result.1)

            let name = param.name.replacingOccurrences(of: "X-", with: "").lowercasingFirst

            return ModelField(description: nil,
                              type: result.0,
                              name: name,
                              required: param.required)
        }, inheritsFrom: [])

        resolvedModelDefinitions.append(.model(model))
        resolvedParameters.append(FunctionParameter(description: nil, name: "headers", typeName: .object(typeName: typeName), required: false))
    }

    // Path

    let pathParams: [FunctionParameter] = parameters.compactMap {
        if case let ParameterLocation.path(type) = $0.location {
            let result = type.toType(typePrefix: typeName, swagger: swagger)
            assert(result.1.count == 0, "A path param isnt expected to contain a special model definition inline, is it?")
            resolvedModelDefinitions.append(contentsOf: result.1)
            return FunctionParameter(description: $0.description, name: $0.name, typeName: result.0, required: $0.required)
        } else {
            return nil
        }
    }

    resolvedParameters.append(contentsOf: pathParams)

    // Query

    let queryParams: [FunctionParameter] = parameters.compactMap {
        if case let ParameterLocation.query(type, _) = $0.location {
            let result = type.toType(typePrefix: typeName, swagger: swagger)
            assert(result.1.count == 0, "A query param isnt expected to contain a special model definition inline, is it?")
            resolvedModelDefinitions.append(contentsOf: result.1)
            return FunctionParameter(description: $0.description, name: $0.name, typeName: result.0, required: $0.required)
        } else {
            return nil
        }
    }

    resolvedParameters.append(contentsOf: queryParams)

    // Body

    let bodyParams: [(FunctionParameter, [ModelDefinition])] = parameters.map {
        if case let ParameterLocation.body(schemaNode) = $0.location {
            let schema = swagger.findSchema(node: schemaNode.value)
            let type = getType(forSchema: schema, typeNamePrefix: typeName, swagger: swagger)
            let param = FunctionParameter(description: $0.description, name: "body", typeName: type.0, required: $0.required)
            return (param, type.1)
        } else {
            return nil
        }
    }.compactMap { $0 }

    resolvedParameters.append(contentsOf: bodyParams.map { $0.0 })
    resolvedModelDefinitions.append(contentsOf: bodyParams.flatMap { $0.1 })

    // CompletionHandler

    let successTypeResult = createResultEnumType(types: responseTypes, failure: false, functionName: functionName, swagger: swagger)
    let successType = successTypeResult.0
    let failureTypeResult = createResultEnumType(types: responseTypes, failure: true, functionName: functionName, swagger: swagger)
    let failureType = failureTypeResult.0
    let completionHandler = FunctionParameter(description: "The completion handler of the function returns as soon as the request completes", name: "completionHandler", typeName: .object(typeName: "@escaping (Result<\(successType), ServiceError<\(failureType)>>) -> Void"), required: true)

    resolvedParameters.append(completionHandler)
    resolvedModelDefinitions.append(contentsOf: successTypeResult.1)
    resolvedModelDefinitions.append(contentsOf: failureTypeResult.1)

    return (resolvedParameters, resolvedModelDefinitions)
}

private func createResultEnumType(types: [(HTTPStatusCodes, TypeType)], failure: Bool, functionName: String, swagger: Swagger) -> (String, [ModelDefinition]) {
    let filteredTypes: [(HTTPStatusCodes, TypeType)]
    if failure {
        filteredTypes = types.filter { !$0.0.isSuccess }
    } else {
        filteredTypes = types.filter { $0.0.isSuccess }
    }

    if filteredTypes.count > 1 {
        let typeName = functionName.components(separatedBy: "_").map { $0.capitalizingFirstLetter() }.joined(separator: "") + (failure ? "Error" : "Success")

        let fields = filteredTypes.map { (statusCode, type) -> String in
            if case TypeType.void = type {
                return statusCode.name
            } else {
                return "\(statusCode.name)(\(type.toString())"
            }
        }

        let enumeration = ModelDefinition.enumeration(Enumeration(serviceName: swagger.serviceName, description: "Result enum", typeName: typeName, values: fields))

        return (typeName, [enumeration])
    } else if filteredTypes.count == 1 {
        return (filteredTypes[0].1.toString(), [])
    } else {
        return ("Void", [])
    }
}
