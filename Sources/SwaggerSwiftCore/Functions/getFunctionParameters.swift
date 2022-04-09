import SwaggerSwiftML

private func resolveInputHeadersToApi(parameters: [SwaggerSwiftML.Parameter], typePrefix: String, isInternalOnly: Bool, swagger: Swagger, swaggerFile: SwaggerFile) -> (FunctionParameter, [ModelDefinition])? {
    let headerParameters = parameters.parameters(of: .header)

    let globalHeaderFieldNames = (swaggerFile.globalHeaders ?? []).map(APIRequestFactory().convertApiHeader)

    var modelDefinitions = [ModelDefinition]()

    let headerFields: [ModelField] = headerParameters.compactMap { param, type, _ in
        let (type, inlineModelDefinitions) = type.toType(
            typePrefix: typePrefix,
            description: param.description,
            swagger: swagger
        )

        let name = APIRequestFactory().convertApiHeader(param.name)

        // we should not add fields for the global headers
        if globalHeaderFieldNames.contains(name) {
            return nil
        }

        modelDefinitions.append(contentsOf: inlineModelDefinitions)

        return ModelField(description: nil,
                          type: type,
                          name: name,
                          required: param.required)
    }.sorted(by: { $0.argumentLabel < $1.argumentLabel })

    if headerFields.count > 0 {
        let typeName = "\(typePrefix)Headers"

        let model = Model(description: "A collection of the header fields required for the request",
                          typeName: typeName,
                          fields: headerFields,
                          inheritsFrom: [],
                          isInternalOnly: isInternalOnly,
                          embeddedDefinitions: [],
                          isCodable: false)

        if model.fields.count > 0 {
            let headerModelDefinition = ModelDefinition.object(model)
            modelDefinitions.append(headerModelDefinition)
            let functionParameter = FunctionParameter(description: nil,
                                                      name: "headers",
                                                      typeName: .object(typeName: typeName),
                                                      required: true,
                                                      in: .headers,
                                                      isEnum: false)

            return (functionParameter, modelDefinitions)
        }
    }

    return nil
}

private func resolvePathParameters(parameters: [SwaggerSwiftML.Parameter], typePrefix: String, swagger: Swagger) -> ([FunctionParameter], [ModelDefinition]) {
    let pathParameters = parameters.parameters(of: .path)

    var modelDefinitions = [ModelDefinition]()
    var functionParameters = [FunctionParameter]()

    for (parameter, paramType, _) in pathParameters {
        let (paramType, embeddedDefinitions) = paramType.toType(typePrefix: typePrefix + parameter.name.uppercasingFirst,
                                                                description: parameter.description,
                                                                swagger: swagger)

        modelDefinitions.append(contentsOf: embeddedDefinitions)

        functionParameters.append(
            FunctionParameter(description: parameter.description,
                              name: parameter.name,
                              typeName: paramType,
                              required: parameter.required,
                              in: .path,
                              isEnum: embeddedDefinitions.count > 0)
        )
    }

    return (functionParameters, modelDefinitions)
}

private func resolveQueryParameters(parameters: [SwaggerSwiftML.Parameter], typePrefix: String, swagger: Swagger) -> ([FunctionParameter], [ModelDefinition]) {
    let queryParameters = parameters.parameters(of: .query)

    var modelDefinitions = [ModelDefinition]()
    var functionParameters = [FunctionParameter]()

    for (parameter, queryType, _) in queryParameters {
        let (paramType, embeddedDefinitions) = queryType.toType(
            typePrefix: typePrefix + parameter.name.uppercasingFirst,
            description: parameter.description,
            swagger: swagger
        )

        modelDefinitions.append(contentsOf: embeddedDefinitions)
        functionParameters.append(
            FunctionParameter(
                description: parameter.description,
                name: parameter.name.camelized,
                typeName: paramType,
                required: parameter.required,
                in: .query,
                isEnum: embeddedDefinitions.count > 0
            )
        )
    }

    return (functionParameters, modelDefinitions)
}

private func resolveBodyParameters(parameters: [SwaggerSwiftML.Parameter], typePrefix: String, swagger: Swagger) -> (FunctionParameter, [ModelDefinition])? {
    let bodyParam = parameters.compactMap { param -> (FunctionParameter, [ModelDefinition])? in
        switch param.location {
        case .body(let schemaNode):
            let schema = swagger.findSchema(node: schemaNode.value)
            let (modelType, inlineModelDefinitions) = getType(forSchema: schema,
                                                              typeNamePrefix: typePrefix,
                                                              swagger: swagger)

            let param = FunctionParameter(description: param.description,
                                          name: "body",
                                          typeName: modelType,
                                          required: param.required,
                                          in: .body,
                                          isEnum: false)

            return (param, inlineModelDefinitions)
        default:
            return nil
        }
    }.first

    if let bodyParam = bodyParam {
        return bodyParam
    } else {
        return nil
    }
}

private func resolveFormDataParameters(parameters: [SwaggerSwiftML.Parameter], typePrefix: String, swagger: Swagger) -> ([FunctionParameter], [ModelDefinition]) {
    let formDataParameters = parameters.parameters(of: .formData)

    var functionParameters = [FunctionParameter]()
    var modelDefinitions = [ModelDefinition]()

    for (parameter, dataType, allowEmpty) in formDataParameters {
        let isRequired = (allowEmpty ?? true) == false
        switch dataType {
        case .string(_, let enumValues, _, _, _):
            if let enumValues = enumValues {
                let typeName = "\(typePrefix)\(parameter.name.camelized.capitalizingFirstLetter())"
                modelDefinitions.append(.enumeration(.init(serviceName: swagger.serviceName,
                                                           description: parameter.description,
                                                           typeName: typeName,
                                                           values: enumValues,
                                                           isCodable: true)))

                let param = FunctionParameter(description: parameter.description,
                                              name: parameter.name,
                                              typeName: .object(typeName: typeName),
                                              required: isRequired,
                                              in: .formData,
                                              isEnum: true)

                functionParameters.append(param)
            } else {
                let typeName = dataType.toType(typePrefix: typePrefix,
                                                description: parameter.description,
                                                swagger: swagger)

                let param = FunctionParameter(description: parameter.description,
                                              name: parameter.name,
                                              typeName: typeName.0,
                                              required: isRequired,
                                              in: .formData,
                                              isEnum: false)

                functionParameters.append(param)
            }
        case .number:
            log("[\(swagger.serviceName)] SwaggerSwift does not currently support number as the data type in a FormData request", error: true)
            continue
        case .integer:
            log("[\(swagger.serviceName)] SwaggerSwift does not currently support integer as the data type in a FormData request", error: true)
            continue
        case .boolean:
            log("[\(swagger.serviceName)] SwaggerSwift does not currently support boolean as the data type in a FormData request", error: true)
            continue
        case .array:
            log("[\(swagger.serviceName)] SwaggerSwift does not currently support array as the data type in a FormData request", error: true)
            continue
        case .file:
            let typeName = dataType.toType(typePrefix: typePrefix,
                                            description: parameter.description,
                                            swagger: swagger)

            let param = FunctionParameter(description: parameter.description,
                                          name: parameter.name,
                                          typeName: typeName.0,
                                          required: isRequired,
                                          in: .formData,
                                          isEnum: false)

            functionParameters.append(param)
        }
    }

    return (functionParameters, modelDefinitions)
}

func resolveInputParameters(for operation: Operation, functionName: String, responseTypes: [ResponseTypeMap], swagger: Swagger, swaggerFile: SwaggerFile) -> ([FunctionParameter], [ModelDefinition]) {
    let parameters = (operation.parameters ?? []).map {
        swagger.findParameter(node: $0)
    }

    var resolvedParameters = [FunctionParameter]()
    var resolvedModelDefinitions = [ModelDefinition]()

    let typeName = functionName.components(separatedBy: "_")
        .map { $0.capitalizingFirstLetter() }
        .joined()

    if let (headerParameter, headerModels) = resolveInputHeadersToApi(parameters: parameters,
                                                                      typePrefix: typeName,
                                                                      isInternalOnly: operation.isInternalOnly,
                                                                      swagger: swagger,
                                                                      swaggerFile: swaggerFile) {
        resolvedParameters.append(headerParameter)
        resolvedModelDefinitions.append(contentsOf: headerModels)
    }

    // Path
    let (pathParameters, pathModels) = resolvePathParameters(parameters: parameters, typePrefix: typeName, swagger: swagger)
    resolvedParameters.append(contentsOf: pathParameters)
    resolvedModelDefinitions.append(contentsOf: pathModels)

    // Query
    let (queryParameters, queryModels) = resolveQueryParameters(parameters: parameters, typePrefix: typeName, swagger: swagger)
    resolvedParameters.append(contentsOf: queryParameters)
    resolvedModelDefinitions.append(contentsOf: queryModels)

    // Body

    if let (bodyParameter, bodyModels) = resolveBodyParameters(parameters: parameters, typePrefix: typeName, swagger: swagger) {
        resolvedParameters.append(bodyParameter)
        resolvedModelDefinitions.append(contentsOf: bodyModels)
    }

    let (formDataParameters, formDataModels) = resolveFormDataParameters(parameters: parameters, typePrefix: typeName, swagger: swagger)
    resolvedParameters.append(contentsOf: formDataParameters)
    resolvedModelDefinitions.append(contentsOf: formDataModels)

    // Completion
    let successTypeResult = createResultEnumType(types: responseTypes, failure: false, functionName: functionName, swagger: swagger)
    let successType = successTypeResult.0

    let failureTypeResult = createResultEnumType(types: responseTypes, failure: true, functionName: functionName, swagger: swagger)
    let failureType = failureTypeResult.0

    let completionHandler = FunctionParameter(
        description: "The completion handler of the function returns as soon as the request completes",
        name: "completion",
        typeName: .object(typeName: "@escaping (Result<\(successType), ServiceError<\(failureType)>>) -> Void = { _ in }"),
        required: true,
        in: .nowhere,
        isEnum: false
    )

    resolvedParameters.append(completionHandler)
    resolvedModelDefinitions.append(contentsOf: successTypeResult.1)
    resolvedModelDefinitions.append(contentsOf: failureTypeResult.1)

    return (resolvedParameters, resolvedModelDefinitions)
}

typealias ResponseTypeMap = (statusCode: HTTPStatusCode, type: TypeType)

private func createResultEnumType(types: [ResponseTypeMap], failure: Bool, functionName: String, swagger: Swagger) -> (String, [ModelDefinition]) {
    let filteredTypes: [(HTTPStatusCode, TypeType)]
    if failure {
        filteredTypes = types.filter { !$0.statusCode.isSuccess }
    } else {
        filteredTypes = types.filter { $0.statusCode.isSuccess }
    }

    if filteredTypes.count > 1 {
        let typeName = functionName.components(separatedBy: "_").map { $0.capitalizingFirstLetter() }.joined(separator: "") + (failure ? "Error" : "Success")

        let fields = filteredTypes.map { (statusCode, type) -> String in
            if case TypeType.void = type {
                return statusCode.name
            } else {
                return "\(statusCode.name)(\(type.toString(required: true)))"
            }
        }

        let enumeration = ModelDefinition.enumeration(
            Enumeration(serviceName: swagger.serviceName,
                        description: nil,
                        typeName: typeName,
                        values: fields,
                        isCodable: false)
        )

        return (typeName, [enumeration])
    } else if filteredTypes.count == 1 {
        return (filteredTypes[0].1.toString(required: true).modelNamed, [])
    } else {
        return ("Void", [])
    }
}
