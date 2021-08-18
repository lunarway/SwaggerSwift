import SwaggerSwiftML

/// Convert the Header name, e.g. `X-AppDeviceVersion` to the field name that is used on the object in the Swift code, e.g. `appDeviceVersion`
/// - Parameter headerName:
/// - Returns: the field name to use in the Swift struct
func makeHeaderFieldName(headerName: String) -> String {
    headerName.replacingOccurrences(of: "X-", with: "")
        .replacingOccurrences(of: "x-", with: "")
        .lowercasingFirst
}

func getFunctionParameters(_ parameters: [Parameter], functionName: String, isInternalOnly: Bool, responseTypes: [(HTTPStatusCodes, TypeType)], swagger: Swagger, swaggerFile: SwaggerFile) -> ([FunctionParameter], [ModelDefinition]) {
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

        let globalHeaderFieldNames = (swaggerFile.globalHeaders ?? []).map { makeHeaderFieldName(headerName: $0) }

        let fields: [ModelField] = headers.compactMap { param, type in
            let resultType = type.toType(typePrefix: typeName, swagger: swagger)
            let name = makeHeaderFieldName(headerName: param.name)

            // we should not add fields for the global headers
            if globalHeaderFieldNames.contains(name) {
                return nil
            }

            resolvedModelDefinitions.append(contentsOf: resultType.1)


            return ModelField(description: nil,
                              type: resultType.0,
                              name: name,
                              required: param.required)
        }.sorted(by: { $0.name < $1.name })

        let model = Model(serviceName: swagger.serviceName,
                          description: "A collection of the header fields required for the request",
                          typeName: typeName,
                          fields: fields,
                          inheritsFrom: [],
                          isInternalOnly: isInternalOnly,
                          embeddedDefinitions: [])

        if model.fields.count > 0 {
            resolvedModelDefinitions.append(.model(model))
            resolvedParameters.append(FunctionParameter(description: nil,
                                                        name: "headers",
                                                        typeName: .object(typeName: typeName),
                                                        required: true,
                                                        in: .headers,
                                                        isEnum: false))
        }
    }

    // Path

    let pathParams: [FunctionParameter] = parameters.compactMap {
        if case let ParameterLocation.path(type) = $0.location {
            let result = type.toType(typePrefix: typeName, swagger: swagger)
            assert(result.1.count == 0, "A path param isnt expected to contain a special model definition inline, is it?")
            resolvedModelDefinitions.append(contentsOf: result.1)
            return FunctionParameter(description: $0.description,
                                     name: $0.name,
                                     typeName: result.0,
                                     required: $0.required,
                                     in: .path,
                                     isEnum: false)
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
            return FunctionParameter(description: $0.description,
                                     name: $0.name.camelized,
                                     typeName: result.0,
                                     required: $0.required,
                                     in: .query,
                                     isEnum: false)
        } else {
            return nil
        }
    }

    resolvedParameters.append(contentsOf: queryParams)

    // Body

    let bodyParams: [(FunctionParameter, [ModelDefinition])] = parameters.compactMap {
        switch $0.location {
        case .body(schema: let schemaNode):
            let schema = swagger.findSchema(node: schemaNode.value)
            let type = getType(forSchema: schema, typeNamePrefix: typeName, swagger: swagger)
            let param = FunctionParameter(description: $0.description, name: "body", typeName: type.0, required: $0.required, in: .body, isEnum: false)
            return (param, type.1)
        case .formData(type: let paramType, allowEmptyValue: let allowEmpty):
            var modelDefinitions = [ModelDefinition]()
            switch paramType {
            case .string(format: _, enumValues: let enumValues, maxLength: _, minLength: _, pattern: _):
                if let enumValues = enumValues {
                    let typeName = "\(typeName)\($0.name.camelized.capitalizingFirstLetter())"
                    modelDefinitions.append(.enumeration(.init(serviceName: swagger.serviceName,
                                                               description: $0.description,
                                                               typeName: typeName,
                                                               values: enumValues,
                                                               isCodable: true)))

                    let param = FunctionParameter(description: $0.description,
                                                  name: $0.name,
                                                  typeName: .object(typeName: typeName),
                                                  required: !allowEmpty,
                                                  in: .formData,
                                                  isEnum: true)

                    return (param, modelDefinitions)
                } else {
                    let typeName = paramType.toType(typePrefix: typeName, swagger: swagger)
                    let param = FunctionParameter(description: $0.description,
                                                  name: $0.name,
                                                  typeName: typeName.0,
                                                  required: !allowEmpty,
                                                  in: .formData,
                                                  isEnum: false)

                    return (param, modelDefinitions)
                }
            case .number(format: _, maximum: _, exclusiveMaximum: _, minimum: _, exclusiveMinimum: _, multipleOf: _):
                fatalError("Not implemented")
            case .integer(format: _, maximum: _, exclusiveMaximum: _, minimum: _, exclusiveMinimum: _, multipleOf: _):
                fatalError("Not implemented")
            case .boolean:
                fatalError("Not implemented")
            case .array(_, collectionFormat: _, maxItems: _, minItems: _, uniqueItems: _):
                fatalError("Not implemented")
            case .file:
                let typeName = paramType.toType(typePrefix: typeName, swagger: swagger)
                let param = FunctionParameter(description: $0.description,
                                              name: $0.name,
                                              typeName: typeName.0,
                                              required: !allowEmpty,
                                              in: .formData,
                                              isEnum: false)

                return (param, modelDefinitions)
            }

        default: return nil
        }
    }

    resolvedParameters.append(contentsOf: bodyParams.map { $0.0 })
    resolvedModelDefinitions.append(contentsOf: bodyParams.flatMap { $0.1 })

    // CompletionHandler

    let successTypeResult = createResultEnumType(types: responseTypes, failure: false, functionName: functionName, swagger: swagger)
    let successType = successTypeResult.0
    let failureTypeResult = createResultEnumType(types: responseTypes, failure: true, functionName: functionName, swagger: swagger)
    let failureType = failureTypeResult.0
    let completionHandler = FunctionParameter(description: "The completion handler of the function returns as soon as the request completes", name: "completionHandler", typeName: .object(typeName: "@escaping (Result<\(successType), ServiceError<\(failureType)>>) -> Void = { _ in }"), required: true, in: .nowhere, isEnum: false)

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
                return "\(statusCode.name)(\(type.toString(required: true)))"
            }
        }

        let enumeration = ModelDefinition.enumeration(Enumeration(serviceName: swagger.serviceName, description: "Result enum", typeName: typeName, values: fields, isCodable: false))

        return (typeName, [enumeration])
    } else if filteredTypes.count == 1 {
        return (filteredTypes[0].1.toString(required: true), [])
    } else {
        return ("Void", [])
    }
}
