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
    func make(
        forOperation operation: SwaggerSwiftML.Operation,
        functionName: String,
        responseTypes: [ResponseTypeMap],
        pathParameters: [Parameter],
        swagger: Swagger,
        swaggerFile: SwaggerFile
    ) throws -> ([FunctionParameter], [ModelDefinition], ReturnType) {
        let parameters: [Parameter] =
            try (operation.parameters ?? []).map(swagger.findParameter(node:)) + pathParameters

        var resolvedParameters = [FunctionParameter]()
        var resolvedModelDefinitions = [ModelDefinition]()

        let typeName = functionName.components(separatedBy: "_")
            .map { $0.capitalizingFirstLetter() }
            .joined()

        if let (headerParameter, headerModels) = try resolveInputHeadersToApi(
            parameters: parameters,
            typePrefix: typeName,
            isInternalOnly: operation.isInternalOnly,
            swagger: swagger,
            swaggerFile: swaggerFile
        ) {
            resolvedParameters.append(headerParameter)
            resolvedModelDefinitions.append(contentsOf: headerModels)
        }

        // Path
        let (pathParameters, pathModels) = try resolvePathParameters(
            parameters: parameters,
            typePrefix: typeName,
            swagger: swagger
        )
        resolvedParameters.append(contentsOf: pathParameters)
        resolvedModelDefinitions.append(contentsOf: pathModels)

        // Query
        let (queryParameters, queryModels) = try resolveQueryParameters(
            parameters: parameters,
            typePrefix: typeName,
            swagger: swagger
        )
        resolvedParameters.append(contentsOf: queryParameters)
        resolvedModelDefinitions.append(contentsOf: queryModels)

        // Body
        if let (bodyParameter, bodyModels) = try resolveBodyParameters(
            parameters: parameters,
            typePrefix: typeName,
            namespace: swagger.serviceName,
            swagger: swagger
        ) {
            resolvedParameters.append(bodyParameter)
            resolvedModelDefinitions.append(contentsOf: bodyModels)
        }

        let (formDataParameters, formDataModels) = try resolveFormDataParameters(
            parameters: parameters,
            typePrefix: typeName,
            swagger: swagger
        )
        resolvedParameters.append(contentsOf: formDataParameters)
        resolvedModelDefinitions.append(contentsOf: formDataModels)

        // Completion
        let (successTypeName, successInlineModels) = createResultEnumType(
            types: responseTypes,
            failure: false,
            functionName: functionName,
            swagger: swagger
        )
        resolvedModelDefinitions.append(contentsOf: successInlineModels)

        let (failureTypeName, failureInlineModels) = createResultEnumType(
            types: responseTypes,
            failure: true,
            functionName: functionName,
            swagger: swagger
        )
        resolvedModelDefinitions.append(contentsOf: failureInlineModels)

        let returnType = ReturnType(
            description:
                "The completion handler of the function returns as soon as the request completes",
            successType: .object(typeName: successTypeName),
            failureType: .object(typeName: "ServiceError<\(failureTypeName)>")
        )

        return (resolvedParameters, resolvedModelDefinitions, returnType)
    }

    private func createResultEnumType(
        types: [ResponseTypeMap],
        failure: Bool,
        functionName: String,
        swagger: Swagger
    ) -> (String, [ModelDefinition]) {
        let filteredTypes: [(HTTPStatusCode, TypeType)]
        if failure {
            filteredTypes = types.filter { !$0.statusCode.isSuccess }
        } else {
            filteredTypes = types.filter { $0.statusCode.isSuccess }
        }

        if filteredTypes.count > 1 {
            let typeName =
                functionName.components(separatedBy: "_").map { $0.capitalizingFirstLetter() }.joined(
                    separator: ""
                ) + (failure ? "Error" : "Success")

            let fields = filteredTypes.map { (statusCode, type) -> String in
                if case TypeType.void = type {
                    return statusCode.name
                } else {
                    return "\(statusCode.name)(\(type.toString(required: true)))"
                }
            }

            let enumeration = ModelDefinition.enumeration(
                Enumeration(
                    serviceName: swagger.serviceName,
                    description: nil,
                    typeName: typeName,
                    values: fields,
                    isCodable: false,
                    collectionFormat: nil
                )
            )

            return (typeName, [enumeration])
        } else if let type = filteredTypes.first?.1 {
            let resultTypeName = type.toString(required: true).modelNamed
            return (resultTypeName, [])
        } else {
            return ("Void", [])
        }
    }

    private func resolveInputHeadersToApi(
        parameters: [SwaggerSwiftML.Parameter],
        typePrefix: String,
        isInternalOnly: Bool,
        swagger: Swagger,
        swaggerFile: SwaggerFile
    ) throws -> (FunctionParameter, [ModelDefinition])? {
        let requestSpecificParameters = parameters.compactMap {
            if case let .header(type) = $0.location {
                return HeaderParameter(
                    type: type,
                    name: $0.name,
                    required: $0.required,
                    description: $0.description
                )
            } else {
                return nil
            }
        }.unique(on: { $0.name })  // this is necessary in the case where copies of the same header are sent in at the same request

        let globalHeaderParams = swaggerFile.globalHeaders
            .filter { header in
                requestSpecificParameters.contains(where: { $0.name.lowercased() == header.lowercased() })
                    == false
            }
            .map {
                HeaderParameter(
                    type: .string(
                        format: nil,
                        enumValues: nil,
                        maxLength: nil,
                        minLength: nil,
                        pattern: nil
                    ),
                    name: $0,
                    required: true,
                    description: nil
                )
            }

        var modelDefinitions = [ModelDefinition]()
        let requestSpecificHeaderFields: [ModelField] = try requestSpecificParameters.map {
            headerParam in
            let (type, inlineModelDefinitions) = try headerParam.type.toType(
                typePrefix: typePrefix,
                description: headerParam.description,
                swagger: swagger
            )

            modelDefinitions.append(contentsOf: inlineModelDefinitions)

            let isRequired: Bool
            if swaggerFile.globalHeaders.contains(where: {
                $0.lowercased() == headerParam.name.lowercased()
            }) {
                isRequired = false  // this is overriden by the global headers so it will be set by that, and is therefor not required here
            } else {
                isRequired = headerParam.required
            }

            return ModelField(
                description: nil,
                type: type,
                name: convertApiHeader(headerParam.name),
                isRequired: isRequired
            )
        }

        let globalHeaderFields =
            globalHeaderParams
            .map {
                ModelField(
                    description: nil,
                    type: .string(defaultValue: nil),
                    name: convertApiHeader($0.name),
                    isRequired: false
                )
            }

        let allHeaderFields = (requestSpecificHeaderFields + globalHeaderFields)
            .sorted(by: { $0.argumentLabel < $1.argumentLabel })

        guard allHeaderFields.count > 0 else { return nil }

        let model = Model(
            description: "A collection of the header fields required for the request",
            typeName: "\(typePrefix)Headers",
            fields: allHeaderFields,
            inheritsFrom: [],
            isInternalOnly: isInternalOnly,
            embeddedDefinitions: [],
            isCodable: false
        )

        modelDefinitions.append(ModelDefinition.object(model))

        let functionParameter = FunctionParameter(
            description: nil,
            name: "headers",
            typeName: .object(typeName: model.typeName),
            required: requestSpecificHeaderFields.count > 0
                && requestSpecificHeaderFields.contains(where: { $0.isRequired }),
            in: .headers,
            isEnum: false
        )

        return (functionParameter, modelDefinitions)
    }

    private func resolvePathParameters(
        parameters: [SwaggerSwiftML.Parameter],
        typePrefix: String,
        swagger: Swagger
    ) throws -> ([FunctionParameter], [ModelDefinition]) {
        let pathParameters = parameters.parameters(of: .path)

        var modelDefinitions = [ModelDefinition]()
        var functionParameters = [FunctionParameter]()

        for (parameter, paramType, _) in pathParameters {
            let (paramType, embeddedDefinitions) = try paramType.toType(
                typePrefix: typePrefix + parameter.name.uppercasingFirst,
                description: parameter.description,
                swagger: swagger
            )

            modelDefinitions.append(contentsOf: embeddedDefinitions)

            functionParameters.append(
                FunctionParameter(
                    description: parameter.description,
                    name: parameter.name,
                    typeName: paramType,
                    required: parameter.required,
                    in: .path,
                    isEnum: embeddedDefinitions.count > 0
                )
            )
        }

        return (functionParameters, modelDefinitions)
    }

    private func resolveQueryParameters(
        parameters: [SwaggerSwiftML.Parameter],
        typePrefix: String,
        swagger: Swagger
    ) throws -> ([FunctionParameter], [ModelDefinition]) {
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

    private func resolveBodyParameters(
        parameters: [SwaggerSwiftML.Parameter],
        typePrefix: String,
        namespace: String,
        swagger: Swagger
    ) throws -> (FunctionParameter, [ModelDefinition])? {
        var schemaNode: Node<Schema>?
        var parameter: Parameter?
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
            let resolvedType = try modelTypeResolver.resolve(
                forSchema: schema,
                typeNamePrefix: typePrefix,
                namespace: namespace,
                swagger: swagger
            )

            let param = FunctionParameter(
                description: parameter.description,
                name: "body",
                typeName: resolvedType.propertyType,
                required: parameter.required,
                in: .body,
                isEnum: false
            )

            return (param, resolvedType.inlineModelDefinitions)
        case .reference(let reference):
            let schema = try swagger.findSchema(reference: reference)
            let modelDefinition = try ModelReference(rawValue: reference)

            let type = schema.type(named: modelDefinition.typeName)

            if case TypeType.array(let typeName) = type {
                let param = FunctionParameter(
                    description: parameter.description,
                    name: "body",
                    typeName: typeName,
                    required: parameter.required,
                    in: .body,
                    isEnum: false
                )
                return (param, [])
            }

            let param = FunctionParameter(
                description: parameter.description,
                name: "body",
                typeName: type,
                required: parameter.required,
                in: .body,
                isEnum: false
            )

            return (param, [])
        }
    }

    private func resolveFormDataParameters(
        parameters: [SwaggerSwiftML.Parameter],
        typePrefix: String,
        swagger: Swagger
    ) throws -> ([FunctionParameter], [ModelDefinition]) {
        let formDataParameters = parameters.parameters(of: .formData)

        var functionParameters = [FunctionParameter]()
        var modelDefinitions = [ModelDefinition]()

        for (parameter, dataType, allowEmpty) in formDataParameters {
            let isRequired = (allowEmpty ?? true) == false
            switch dataType {
            case .string(_, let enumValues, _, _, _):
                if let enumValues = enumValues {
                    let typeName = "\(typePrefix)\(parameter.name.camelized.capitalizingFirstLetter())"
                    modelDefinitions.append(
                        .enumeration(
                            .init(
                                serviceName: swagger.serviceName,
                                description: parameter.description,
                                typeName: typeName,
                                values: enumValues,
                                isCodable: true,
                                collectionFormat: nil
                            )
                        )
                    )

                    let param = FunctionParameter(
                        description: parameter.description,
                        name: parameter.name,
                        typeName: .object(typeName: typeName),
                        required: isRequired,
                        in: .formData,
                        isEnum: true
                    )

                    functionParameters.append(param)
                } else {
                    let typeName = try dataType.toType(
                        typePrefix: typePrefix,
                        description: parameter.description,
                        swagger: swagger
                    )

                    let param = FunctionParameter(
                        description: parameter.description,
                        name: parameter.name,
                        typeName: typeName.0,
                        required: isRequired,
                        in: .formData,
                        isEnum: false
                    )

                    functionParameters.append(param)
                }
            case .number:
                log(
                    "[\(swagger.serviceName)] SwaggerSwift does not currently support number as the data type in a FormData request",
                    error: true
                )
                continue
            case .integer:
                log(
                    "[\(swagger.serviceName)] SwaggerSwift does not currently support integer as the data type in a FormData request",
                    error: true
                )
                continue
            case .boolean:
                log(
                    "[\(swagger.serviceName)] SwaggerSwift does not currently support boolean as the data type in a FormData request",
                    error: true
                )
                continue
            case .array:
                log(
                    "[\(swagger.serviceName)] SwaggerSwift does not currently support array as the data type in a FormData request",
                    error: true
                )
                continue
            case .file:
                let typeName = try dataType.toType(
                    typePrefix: typePrefix,
                    description: parameter.description,
                    swagger: swagger
                )

                let param = FunctionParameter(
                    description: parameter.description,
                    name: parameter.name,
                    typeName: typeName.0,
                    required: isRequired,
                    in: .formData,
                    isEnum: false
                )

                functionParameters.append(param)
            }
        }

        return (functionParameters, modelDefinitions)
    }
}

extension Sequence {
    func unique<T: Equatable>(on block: (Iterator.Element) -> T) -> [Self.Element] {
        var result = [Iterator.Element]()

        for item in self {
            if result.contains(where: { r in block(item) == block(r) }) == false {
                result.append(item)
            }
        }

        return result
    }
}
