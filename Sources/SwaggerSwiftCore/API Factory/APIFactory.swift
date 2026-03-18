import Foundation
import SwaggerSwiftML

struct APIFactory {
    let apiRequestFactory: APIRequestFactory
    let modelTypeResolver: ModelTypeResolver

    func generate(for swagger: Swagger, withSwaggerFile swaggerFile: SwaggerFile) throws -> (
        APIDefinition, [ModelDefinition]
    ) {
        let (apiFunctions, inlineModelDefinitions) = try getApiList(
            fromSwagger: swagger,
            swaggerFile: swaggerFile
        )
        let modelDefinitions = try getModelDefinitions(fromSwagger: swagger)
        let responseModelDefinitions = try getResponseModelDefinitions(fromSwagger: swagger)

        // Model Definitions can be a lot of things - when resolving the inheritance tree for
        // the model definitions we just need the actual models, and a model can only inherit
        // from the global swagger model definitions
        let models = modelDefinitions.compactMap { model -> Model? in
            if case ModelDefinition.object(let model) = model {
                return model
            } else {
                return nil
            }
        }

        let totalSetOfModelDefinitions = modelDefinitions + inlineModelDefinitions
        let resolvedModelDefinitions = totalSetOfModelDefinitions.map {
            $0.resolveInheritanceTree(with: models)
        }
        let allModelDefinitions = resolvedModelDefinitions + responseModelDefinitions
        let optimizedModelDefinitions = optimizeModelConformance(
            in: allModelDefinitions,
            apiRequests: apiFunctions
        )

        let apiDefinitionFields = apiDefinitionsModelFields(swaggerFile: swaggerFile)

        let apiDefinition = APIDefinition(
            serviceName: swagger.serviceName,
            description: swagger.info.description?.trimmingCharacters(
                in: CharacterSet.whitespacesAndNewlines
            ),
            fields: apiDefinitionFields,
            functions: apiFunctions
        )

        return (apiDefinition, optimizedModelDefinitions)
    }

    private static let typeNameTokenRegex = try! NSRegularExpression(
        pattern: "[A-Za-z_][A-Za-z0-9_.]*"
    )

    private func optimizeModelConformance(
        in modelDefinitions: [ModelDefinition],
        apiRequests: [APIRequest]
    ) -> [ModelDefinition] {
        let availableTypeNames = Set(modelDefinitions.map(\.typeName))

        let dependencyMap = buildModelDependencyMap(
            from: modelDefinitions,
            availableTypeNames: availableTypeNames
        )

        let requestSeedTypes = requestModelTypeNames(
            in: apiRequests,
            availableTypeNames: availableTypeNames
        )
        let responseSeedTypes = responseModelTypeNames(
            in: apiRequests,
            availableTypeNames: availableTypeNames
        )

        let encodableModelTypes = propagatedModelTypes(
            from: requestSeedTypes,
            dependencyMap: dependencyMap
        )
        let decodableModelTypes = propagatedModelTypes(
            from: responseSeedTypes,
            dependencyMap: dependencyMap
        )

        return modelDefinitions.map { definition in
            guard definition.supportsCodableConformanceOptimization else {
                return definition
            }

            let resolvedConformance = ModelCodingConformance.from(
                isEncodable: encodableModelTypes.contains(definition.typeName),
                isDecodable: decodableModelTypes.contains(definition.typeName)
            )

            // Keep backwards compatibility for models whose direction cannot be inferred.
            let targetConformance: ModelCodingConformance =
                resolvedConformance == .none ? .codable : resolvedConformance

            return definition.withConformance(targetConformance)
        }
    }

    private func buildModelDependencyMap(
        from modelDefinitions: [ModelDefinition],
        availableTypeNames: Set<String>
    ) -> [String: Set<String>] {
        var dependencyMap = [String: Set<String>]()

        for definition in modelDefinitions {
            let typeReferences: Set<String>

            switch definition {
            case .object(let model):
                typeReferences = Set(
                    model.fields.flatMap {
                        referencedModelTypeNames(
                            in: $0.type,
                            availableTypeNames: availableTypeNames
                        )
                    }
                )
            case .array(let model):
                typeReferences = referencedModelTypeNames(
                    inTypeString: model.containsType,
                    availableTypeNames: availableTypeNames
                )
            case .typeAlias(let model):
                typeReferences = referencedModelTypeNames(
                    inTypeString: model.type,
                    availableTypeNames: availableTypeNames
                )
            case .enumeration:
                typeReferences = []
            }

            dependencyMap[definition.typeName] = typeReferences.subtracting([definition.typeName])
        }

        return dependencyMap
    }

    private func requestModelTypeNames(
        in apiRequests: [APIRequest],
        availableTypeNames: Set<String>
    ) -> Set<String> {
        var typeNames = Set<String>()

        for apiRequest in apiRequests {
            for parameter in apiRequest.parameters where parameter.in != .nowhere {
                typeNames.formUnion(
                    referencedModelTypeNames(
                        in: parameter.typeName,
                        availableTypeNames: availableTypeNames
                    )
                )
            }
        }

        return typeNames
    }

    private func responseModelTypeNames(
        in apiRequests: [APIRequest],
        availableTypeNames: Set<String>
    ) -> Set<String> {
        var typeNames = Set<String>()

        for apiRequest in apiRequests {
            for responseType in apiRequest.responseTypes {
                switch responseType {
                case .object(_, _, let typeName),
                    .array(_, _, let typeName),
                    .enumeration(_, _, let typeName):
                    typeNames.formUnion(
                        referencedModelTypeNames(
                            inTypeString: typeName,
                            availableTypeNames: availableTypeNames
                        )
                    )
                default:
                    break
                }
            }
        }

        return typeNames
    }

    private func propagatedModelTypes(
        from seedTypes: Set<String>,
        dependencyMap: [String: Set<String>]
    ) -> Set<String> {
        var resolvedTypes = seedTypes
        var queue = Array(seedTypes)

        while let current = queue.popLast() {
            for dependency in dependencyMap[current, default: []] {
                guard !resolvedTypes.contains(dependency) else { continue }
                resolvedTypes.insert(dependency)
                queue.append(dependency)
            }
        }

        return resolvedTypes
    }

    private func referencedModelTypeNames(
        in type: TypeType,
        availableTypeNames: Set<String>
    ) -> Set<String> {
        switch type {
        case .array(let wrappedType):
            return referencedModelTypeNames(
                in: wrappedType,
                availableTypeNames: availableTypeNames
            )
        case .object(let typeName), .enumeration(let typeName):
            return referencedModelTypeNames(
                inTypeString: typeName,
                availableTypeNames: availableTypeNames
            )
        case .typeAlias(let typeName, let wrappedType):
            return referencedModelTypeNames(
                inTypeString: typeName,
                availableTypeNames: availableTypeNames
            ).union(
                referencedModelTypeNames(
                    in: wrappedType,
                    availableTypeNames: availableTypeNames
                )
            )
        case .string, .int, .double, .float, .boolean, .int64, .date, .void:
            return []
        }
    }

    private func referencedModelTypeNames(
        inTypeString typeName: String,
        availableTypeNames: Set<String>
    ) -> Set<String> {
        let nsRange = NSRange(typeName.startIndex..<typeName.endIndex, in: typeName)
        let matches = Self.typeNameTokenRegex.matches(in: typeName, range: nsRange)

        var referencedTypeNames = Set<String>()
        for match in matches {
            guard let tokenRange = Range(match.range, in: typeName) else { continue }

            let token = String(typeName[tokenRange])
            let shortTypeName = token.split(separator: ".").last.map(String.init) ?? token

            if availableTypeNames.contains(shortTypeName) {
                referencedTypeNames.insert(shortTypeName)
            }
        }

        return referencedTypeNames
    }

    /// Parse all service paths in the swagger - get the request function models, and all the inline model definitions
    /// - Parameter swagger: the swagger
    /// - Parameter swaggerFile: the swagger file
    /// - Returns: the list of APIs and any inline model definitions found in the paths
    private func getApiList(fromSwagger swagger: Swagger, swaggerFile: SwaggerFile) throws -> (
        [APIRequest], [ModelDefinition]
    ) {
        var networkRequestFunctions = [APIRequest]()
        var inlineModelDefinitions = [ModelDefinition]()
        for swaggerPath in swagger.paths where !swaggerFile.ignoredPaths.contains(swaggerPath.key) {
            let (pathNetworkRequestFunctions, pathCurrentInlineDefinitions) = try apisAndModels(
                fromPath: swaggerPath.value,
                servicePath: swaggerPath.key,
                swagger: swagger,
                swaggerFile: swaggerFile
            )

            networkRequestFunctions.append(contentsOf: pathNetworkRequestFunctions)
            inlineModelDefinitions.append(contentsOf: pathCurrentInlineDefinitions)
        }

        return (networkRequestFunctions, inlineModelDefinitions)
    }

    func apisAndModels(
        fromPath path: SwaggerSwiftML.Path,
        servicePath: String,
        swagger: Swagger,
        swaggerFile: SwaggerFile
    ) throws -> ([APIRequest], [ModelDefinition]) {
        var apis = [APIRequest]()
        var modelDefinitions = [ModelDefinition]()

        let parameters: [Parameter] = try (path.parameters ?? []).map(swagger.findParameter(node:))

        for httpMethod in HTTPMethod.allCases {
            guard let operation = path.operationForMethod(httpMethod)
            else { continue }

            let (requestFunctions, inlineModelDefinitions) = try apiRequestFactory.generateRequest(
                for: operation,
                httpMethod: httpMethod,
                servicePath: servicePath,
                swagger: swagger,
                swaggerFile: swaggerFile,
                pathParameters: parameters
            )

            apis.append(requestFunctions)
            modelDefinitions.append(contentsOf: inlineModelDefinitions)
        }

        return (apis, modelDefinitions)
    }

    /// Get the global set of model definitions. This is the normal specified list, and not the inline definitions that are defined in e.g. path definitions and other places
    /// - Parameter swagger: the swagger
    /// - Returns: model definitions
    private func getModelDefinitions(fromSwagger swagger: Swagger) throws -> [ModelDefinition] {
        guard let definitions = swagger.definitions else {
            return []
        }

        var allDefinitions = [ModelDefinition]()
        for (typeName, schemaNode) in definitions {
            if case .reference(let reference) = schemaNode {
                allDefinitions.append(
                    .typeAlias(.init(typeName: typeName, type: String(reference.split(separator: "/").last!)))
                )
            }

            guard case .node(let schema) = schemaNode else { continue }

            let resolved = try modelTypeResolver.resolve(
                forSchema: schema,
                typeNamePrefix: typeName,
                namespace: swagger.serviceName,
                swagger: swagger
            )

            allDefinitions.append(contentsOf: resolved.inlineModelDefinitions)

            switch resolved.propertyType {
            case .typeAlias(let typeName, let type):
                allDefinitions.append(
                    .typeAlias(.init(typeName: typeName, type: type.toString(required: true)))
                )
            case .array(let containsType):
                let arrayModel = ModelDefinition.array(
                    .init(
                        description: schema.description,
                        typeName: typeName,
                        containsType: containsType.toString(required: true)
                    )
                )
                allDefinitions.append(arrayModel)
            case .string:
                allDefinitions.append(
                    .typeAlias(.init(typeName: typeName, type: "String"))
                )
            case .int:
                allDefinitions.append(
                    .typeAlias(.init(typeName: typeName, type: "Int"))
                )
            case .double:
                allDefinitions.append(
                    .typeAlias(.init(typeName: typeName, type: "Double"))
                )
            case .float:
                allDefinitions.append(
                    .typeAlias(.init(typeName: typeName, type: "Double"))
                )
            case .boolean:
                allDefinitions.append(
                    .typeAlias(.init(typeName: typeName, type: "Bool"))
                )
            case .int64:
                allDefinitions.append(
                    .typeAlias(.init(typeName: typeName, type: "Int64"))
                )
            case .date:
                allDefinitions.append(
                    .typeAlias(.init(typeName: typeName, type: "Date"))
                )
            case .void:
                allDefinitions.append(
                    .typeAlias(.init(typeName: typeName, type: "Void"))
                )
            case .object: break
            case .enumeration: break
            }
        }

        return allDefinitions
    }

    /// Get the global set of response model definitions
    /// - Parameter swagger: the swagger
    /// - Returns: the set of global response model definitions
    private func getResponseModelDefinitions(fromSwagger swagger: Swagger) throws -> [ModelDefinition] {
        var modelDefinitions = [ModelDefinition]()
        for (typeName, response) in swagger.responses ?? [:] {
            guard let schema = response.schema else {
                if response.headers != nil {
                    log(
                        "SwaggerSwift does currently not support models without schema but with defined headers"
                    )
                    /// TODO: Add support for this
                    /// Example:
                    ///  RedirectResponse:
                    ///    description: Response used to redirect the client to Location
                    ///    headers:
                    ///      Location:
                    ///        type: string
                }

                continue
            }

            switch schema {
            case .reference(let reference):
                if let typeSchema = try? swagger.findSchema(reference: reference) {
                    // we dont need the type part as it just represents the primary model definition returned from this function
                    let resolvedModel = try modelTypeResolver.resolve(
                        forSchema: typeSchema,
                        typeNamePrefix: typeName,
                        namespace: swagger.serviceName,
                        swagger: swagger
                    )
                    modelDefinitions.append(contentsOf: resolvedModel.inlineModelDefinitions)
                } else {
                    log(
                        "[\(swagger.serviceName)] Failed to find definition for reference: \(reference)",
                        error: true
                    )
                    continue
                }
            case .node(let schema):
                // we dont need the type part as it just represents the primary model definition returned from this function
                let resolvedModel = try modelTypeResolver.resolve(
                    forSchema: schema,
                    typeNamePrefix: typeName,
                    namespace: swagger.serviceName,
                    swagger: swagger
                )
                modelDefinitions.append(contentsOf: resolvedModel.inlineModelDefinitions)
            }
        }

        return modelDefinitions
    }

    /// The model fields for the API definition
    /// - Parameter swaggerFile: the swagger file
    /// - Returns: the model fields
    private func apiDefinitionsModelFields(swaggerFile: SwaggerFile) -> [APIDefinitionField] {
        var fields = [
            APIDefinitionField(
                name: "urlSession",
                description:
                    "the underlying URLSession. This is an autoclosure to allow updated instances to come into this instance.",
                typeName: "() async -> URLSession",
                isRequired: true,
                typeIsAutoclosure: false,
                typeIsBlock: true,
                defaultValue: nil
            ),
            APIDefinitionField(
                name: "baseUrlProvider",
                description:
                    "the block provider for the baseUrl of the service. The reason this is a block is that this enables automatically updating the network layer on backend environment change.",
                typeName: "() async -> URL",
                isRequired: true,
                typeIsAutoclosure: false,
                typeIsBlock: true,
                defaultValue: nil
            ),
        ]

        let hasGlobalHeaders = swaggerFile.globalHeaders.count > 0

        if hasGlobalHeaders {
            fields.append(
                APIDefinitionField(
                    name: "headerProvider",
                    description: "a block provider for the set of globally defined headers",
                    typeName: "() async -> any GlobalHeaders",
                    isRequired: true,
                    typeIsAutoclosure: false,
                    typeIsBlock: true,
                    defaultValue: nil
                )
            )
        }

        fields.append(
            APIDefinitionField(
                name: "interceptor",
                description: "use this if you need to intercept overall requests",
                typeName: "(any NetworkInterceptor)",
                isRequired: false,
                typeIsAutoclosure: false,
                typeIsBlock: false,
                defaultValue: "nil"
            )
        )

        return fields
    }
}
