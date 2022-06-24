import Foundation
import SwaggerSwiftML

typealias ResponseTypeMap = (statusCode: HTTPStatusCode, type: TypeType)

public struct RequestParameterFactory {
    let modelTypeResolver: ModelTypeResolver

    public init(modelTypeResolver: ModelTypeResolver) {
        self.modelTypeResolver = modelTypeResolver
    }

    /// Get a list of all the types of parameters that should be supplied to the API request function
    /// - Parameters:
    ///   - operation: the operation representing the api request
    ///   - functionName: the name of the function
    ///   - responseTypes: the types of responses - used to create the completion handler for the request (this is also a "parameter" to the function, just not one that is based on the swagger spec specifically)
    ///   - swagger: the swagger spec
    ///   - swaggerFile: the swagger file
    /// - Returns: the list of all parameters to the API request
    func make(forOperation operation: SwaggerSwiftML.Operation, functionName: String, responseTypes: [ResponseTypeMap], pathParameters: [Parameter], swagger: Swagger, swaggerFile: SwaggerFile) throws -> ([FunctionParameter], [ModelDefinition]) {
        let parameters = (operation.parameters ?? []).map {
            swagger.findParameter(node: $0)
        } + pathParameters

        var resolvedParameters = [FunctionParameter]()
        var resolvedModelDefinitions = [ModelDefinition]()

        let typeName = functionName.components(separatedBy: "_")
            .map { $0.capitalizingFirstLetter() }
            .joined()

        if let (headerParameter, headerModels) = try resolveInputHeadersToApi(parameters: parameters,
                                                                              typePrefix: typeName,
                                                                              isInternalOnly: operation.isInternalOnly,
                                                                              swagger: swagger,
                                                                              swaggerFile: swaggerFile) {
            resolvedParameters.append(headerParameter)
            resolvedModelDefinitions.append(contentsOf: headerModels)
        }

        // Path
        let (pathParameters, pathModels) = try resolvePathParameters(parameters: parameters, typePrefix: typeName, swagger: swagger)
        resolvedParameters.append(contentsOf: pathParameters)
        resolvedModelDefinitions.append(contentsOf: pathModels)

        // Query
        let (queryParameters, queryModels) = try resolveQueryParameters(parameters: parameters, typePrefix: typeName, swagger: swagger)
        resolvedParameters.append(contentsOf: queryParameters)
        resolvedModelDefinitions.append(contentsOf: queryModels)

        // Body
        if let (bodyParameter, bodyModels) = resolveBodyParameters(parameters: parameters,
                                                                   typePrefix: typeName,
                                                                   namespace: swagger.serviceName,
                                                                   swagger: swagger) {
            resolvedParameters.append(bodyParameter)
            resolvedModelDefinitions.append(contentsOf: bodyModels)
        }

        let (formDataParameters, formDataModels) = try resolveFormDataParameters(parameters: parameters, typePrefix: typeName, swagger: swagger)
        resolvedParameters.append(contentsOf: formDataParameters)
        resolvedModelDefinitions.append(contentsOf: formDataModels)

        // Completion
        let (successTypeName, successInlineModels) = createResultEnumType(types: responseTypes, failure: false, functionName: functionName, swagger: swagger)
        resolvedModelDefinitions.append(contentsOf: successInlineModels)
        let (failureTypeName, failureInlineModels) = createResultEnumType(types: responseTypes, failure: true, functionName: functionName, swagger: swagger)
        resolvedModelDefinitions.append(contentsOf: failureInlineModels)

        let completionHandler = FunctionParameter(
            description: "The completion handler of the function returns as soon as the request completes",
            name: "completion",
            typeName: .object(typeName: "@escaping (Result<\(successTypeName), ServiceError<\(failureTypeName)>>) -> Void = { _ in }"),
            required: true,
            in: .nowhere,
            isEnum: false
        )

        resolvedParameters.append(completionHandler)

        return (resolvedParameters, resolvedModelDefinitions)
    }

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
        } else if let type = filteredTypes.first?.1 {
            let resultTypeName = type.toString(required: true).modelNamed
            return (resultTypeName, [])
        } else {
            return ("Void", [])
        }
    }

    private func resolveInputHeadersToApi(parameters: [SwaggerSwiftML.Parameter], typePrefix: String, isInternalOnly: Bool, swagger: Swagger, swaggerFile: SwaggerFile) throws -> (FunctionParameter, [ModelDefinition])? {
        let headerParameters = parameters.parameters(of: .header)

        let globalHeaderFieldNames = (swaggerFile.globalHeaders ?? []).map(convertApiHeader)

        var modelDefinitions = [ModelDefinition]()

        let headerFields: [ModelField] = try headerParameters.compactMap { param, type, _ in
            let (type, inlineModelDefinitions) = try type.toType(
                typePrefix: typePrefix,
                description: param.description,
                swagger: swagger
            )

            let name = convertApiHeader(param.name)

            // we should not add fields for the global headers
            if globalHeaderFieldNames.contains(name) {
                return nil
            }

            modelDefinitions.append(contentsOf: inlineModelDefinitions)

            return ModelField(description: nil,
                              type: type,
                              name: name,
                              isRequired: param.required)
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

    private func resolvePathParameters(parameters: [SwaggerSwiftML.Parameter], typePrefix: String, swagger: Swagger) throws -> ([FunctionParameter], [ModelDefinition]) {
        let pathParameters = parameters.parameters(of: .path)

        var modelDefinitions = [ModelDefinition]()
        var functionParameters = [FunctionParameter]()

        for (parameter, paramType, _) in pathParameters {
            let (paramType, embeddedDefinitions) = try paramType.toType(typePrefix: typePrefix + parameter.name.uppercasingFirst,
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

    private func resolveQueryParameters(parameters: [SwaggerSwiftML.Parameter], typePrefix: String, swagger: Swagger) throws -> ([FunctionParameter], [ModelDefinition]) {
        let queryParameters = parameters.parameters(of: .query)

        var modelDefinitions = [ModelDefinition]()
        var functionParameters = [FunctionParameter]()

        for (parameter, queryType, _) in queryParameters {
            let (paramType, embeddedDefinitions) = try queryType.toType(
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

    private func resolveBodyParameters(parameters: [SwaggerSwiftML.Parameter], typePrefix: String, namespace: String, swagger: Swagger) -> (FunctionParameter, [ModelDefinition])? {
        var schemaNode: Node<Schema>? = nil
        var parameter: Parameter? = nil
        for param in parameters {
            if case let ParameterLocation.body(schema) = param.location {
                schemaNode = schema.value
                parameter = param
                break
            }
        }

        guard let schemaNode = schemaNode, let parameter = parameter else {
            return nil
        }

        switch schemaNode {
        case .node(let schema):
            let resolvedType = modelTypeResolver.resolve(forSchema: schema,
                                                         typeNamePrefix: typePrefix,
                                                         namespace: namespace,
                                                         swagger: swagger)

            let param = FunctionParameter(description: parameter.description,
                                          name: "body",
                                          typeName: resolvedType.propertyType,
                                          required: parameter.required,
                                          in: .body,
                                          isEnum: false)

            return (param, resolvedType.inlineModelDefinitions)
        case .reference(let reference):
            guard let schema = swagger.findSchema(reference: reference) else {
                return nil
            }

            guard let modelDefinition = ModelReference(rawValue: reference) else {
                return nil
            }

            let type = schema.type(named: modelDefinition.typeName)

            if case TypeType.array(let typeName) = type {
                let param = FunctionParameter(description: parameter.description,
                                              name: "body",
                                              typeName: typeName,
                                              required: parameter.required,
                                              in: .body,
                                              isEnum: false)
                return (param, [])
            }

            let param = FunctionParameter(description: parameter.description,
                                          name: "body",
                                          typeName: type,
                                          required: parameter.required,
                                          in: .body,
                                          isEnum: false)

            return (param, [])
        }
    }

    private func resolveFormDataParameters(parameters: [SwaggerSwiftML.Parameter], typePrefix: String, swagger: Swagger) throws -> ([FunctionParameter], [ModelDefinition]) {
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
                    let typeName = try dataType.toType(typePrefix: typePrefix,
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
                let typeName = try dataType.toType(typePrefix: typePrefix,
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
}
