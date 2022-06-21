import Foundation
import SwaggerSwiftML

struct APIFactory {
    let apiRequestFactory: APIRequestFactory
    let modelTypeResolver: ModelTypeResolver


    func resolvePrimitiveAliasesIn(_ modelDefinitions: [ModelDefinition]) {

    }
    
    func generate(for swagger: Swagger, withSwaggerFile swaggerFile: SwaggerFile) throws -> (APIDefinition, [ModelDefinition]) {
        let (apiFunctions, inlineModelDefinitions) = try getApiList(fromSwagger: swagger, swaggerFile: swaggerFile)
        let modelDefinitions = getModelDefinitions(fromSwagger: swagger)
        let responseModelDefinitions = getResponseModelDefinitions(fromSwagger: swagger)

        // Model Definitions can be a lot of things - when resolving the inheritance tree for
        // the model definitions we just need the actual models, and a model can only inherit
        // from the global swagger model definitions
        let models = modelDefinitions.compactMap { model -> Model? in
            if case let ModelDefinition.object(model) = model {
                return model
            } else {
                return nil
            }
        }

        let totalSetOfModelDefinitions = modelDefinitions + inlineModelDefinitions
        let resolvedModelDefinitions = totalSetOfModelDefinitions.map { $0.resolveInheritanceTree(with: models) }
        let allModelDefinitions = resolvedModelDefinitions + responseModelDefinitions

        let apiDefinitionFields = apiDefinitionsModelFields(swaggerFile: swaggerFile)

        let apiDefinition = APIDefinition(
            serviceName: swagger.serviceName,
            description: swagger.info.description?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines),
            fields: apiDefinitionFields,
            functions: apiFunctions
        )

        return (apiDefinition, allModelDefinitions)
    }

    /// Parse all service paths in the swagger - get the request function models, and all the inline model definitions
    /// - Parameter swagger: the swagger
    /// - Parameter swaggerFile: the swagger file
    /// - Returns: the list of APIs and any inline model definitions found in the paths
    private func getApiList(fromSwagger swagger: Swagger, swaggerFile: SwaggerFile) throws -> ([APIRequest], [ModelDefinition]) {
        var networkRequestFunctions = [APIRequest]()
        var inlineModelDefinitions = [ModelDefinition]()
        for swaggerPath in swagger.paths {
            let (pathNetworkRequestFunctions, pathCurrentInlineDefinitions) = try apisAndModels(fromPath: swaggerPath.value,
                                                                                                servicePath: swaggerPath.key,
                                                                                                swagger: swagger,
                                                                                                swaggerFile: swaggerFile)

            networkRequestFunctions.append(contentsOf: pathNetworkRequestFunctions)
            inlineModelDefinitions.append(contentsOf: pathCurrentInlineDefinitions)
        }

        return (networkRequestFunctions, inlineModelDefinitions)
    }

    func apisAndModels(fromPath path: SwaggerSwiftML.Path, servicePath: String, swagger: Swagger, swaggerFile: SwaggerFile) throws -> ([APIRequest], [ModelDefinition]) {
        var apis = [APIRequest]()
        var modelDefinitions = [ModelDefinition]()

        let parameters: [Parameter] = (path.parameters ?? []).map {
            return swagger.findParameter(node: $0)
        }

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



    /// Resolve and replace type definitions in fields of all models that turned out to be primitive aliases.
    /// A primitive alias is a definition of a primitive type, that is not an enum or does not have a handled format.
    ///  E.g. a primitive type alias is a definition of type `string` with format `Decimal` where we don't have a handle for decimal,
    /// - Parameters:
    ///   - modelDefinitions: A list of model definitions that still contains aliases
    ///   - primitiveAliasTypeMapping: the mapping from type name to type
    /// - Returns: a list of model definitions with all primitive aliases resolved to primitive types.
    private func resolveAliasesFor(_ modelDefinitions: [ModelDefinition], with primitiveAliasTypeMapping: [String: TypeType]) -> [ModelDefinition] {
        return modelDefinitions.map { definition in
            if case ModelDefinition.object(let model) = definition {
                let fields = model.fields.map { field -> ModelField in
                    if case TypeType.object(let typeName) = field.type,
                       let type = primitiveAliasTypeMapping[typeName] {
                        return ModelField(description: field.description,
                                          type: type,
                                          name: field.argumentLabel,
                                          isRequired: field.isRequired)
                    } else {
                        return field
                    }
                }
                return .object(.init(description: model.description,
                                     typeName: model.typeName,
                                     fields: fields,
                                     inheritsFrom: model.inheritsFrom,
                                     isInternalOnly: model.isInternalOnly,
                                     embeddedDefinitions: model.embeddedDefinitions,
                                     isCodable: model.isCodable))

            } else {
                return definition
            }
        }
    }

    /// Get the global set of model definitions. This is the normal specified list, and not the inline definitions that are defined in e.g. path definitions and other places
    /// - Parameter swagger: the swagger
    /// - Returns: model definitions
    private func getModelDefinitions(fromSwagger swagger: Swagger) -> [ModelDefinition] {
        guard let definitions = swagger.definitions else {
            return []
        }

        var allDefinitions = [ModelDefinition]()
        var primitiveAliasTypeMapping = [String: TypeType]()
        for (typeName, schema) in definitions {
            let resolved = modelTypeResolver.resolve(forSchema: schema,
                                                     typeNamePrefix: typeName,
                                                     namespace: swagger.serviceName,
                                                     swagger: swagger)

            allDefinitions.append(contentsOf: resolved.inlineModelDefinitions)

            switch resolved.propertyType {
            case .array(let containsType):
                let arrayModel = ModelDefinition.array(.init(description: schema.description, typeName: typeName, containsType: containsType.toString(required: true)))
                allDefinitions.append(arrayModel)
            case .string:
                primitiveAliasTypeMapping[swagger.serviceName + "." + typeName] = .string
            case .int:
                break
            case .double:
                break
            case .float:
                break
            case .boolean:
                break
            case .int64:
                break
            case .date:
                break
            case .void:
                break
            case .object:
                break
            case .enumeration:
                break
            }
        }
        return resolveAliasesFor(allDefinitions, with: primitiveAliasTypeMapping)
    }

    /// Get the global set of response model definitions
    /// - Parameter swagger: the swagger
    /// - Returns: the set of global response model definitions
    private func getResponseModelDefinitions(fromSwagger swagger: Swagger) -> [ModelDefinition] {
        var modelDefinitions = [ModelDefinition]()
        for (typeName, response) in swagger.responses ?? [:] {
            guard let schema = response.schema else {
                if response.headers != nil {
                    log("SwaggerSwift does currently not support models without schema but with defined headers")
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
                if let (_, typeSchema) = swagger.definitions?.first(where: { reference == "#/definitions/\($0.key)" }) {
                    // we dont need the type part as it just represents the primary model definition returned from this function
                    let resolvedModel = modelTypeResolver.resolve(forSchema: typeSchema,
                                                                  typeNamePrefix: typeName,
                                                                  namespace: swagger.serviceName,
                                                                  swagger: swagger)
                    modelDefinitions.append(contentsOf: resolvedModel.inlineModelDefinitions)
                } else {
                    log("[\(swagger.serviceName)] Failed to find definition for reference: \(reference)", error: true)
                    continue
                }
            case .node(let schema):
                // we dont need the type part as it just represents the primary model definition returned from this function
                let resolvedModel = modelTypeResolver.resolve(forSchema: schema,
                                                              typeNamePrefix: typeName,
                                                              namespace: swagger.serviceName,
                                                              swagger: swagger)
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
            APIDefinitionField(name: "urlSession",
                               description: "the underlying URLSession. This is an autoclosure to allow updated instances to come into this instance.",
                               typeName: "() -> URLSession",
                               isRequired: true,
                               typeIsAutoclosure: false,
                               typeIsBlock: true,
                               defaultValue: nil),
            APIDefinitionField(name: "baseUrlProvider",
                               description: "the block provider for the baseUrl of the service. The reason this is a block is that this enables automatically updating the network layer on backend environment change.",
                               typeName: "() -> URL",
                               isRequired: true,
                               typeIsAutoclosure: false,
                               typeIsBlock: true,
                               defaultValue: nil)
        ]

        let hasGlobalHeaders = (swaggerFile.globalHeaders ?? []).count > 0

        if hasGlobalHeaders {
            fields.append(APIDefinitionField(name: "headerProvider",
                                             description: "a block provider for the set of globally defined headers",
                                             typeName: "() -> GlobalHeaders",
                                             isRequired: true,
                                             typeIsAutoclosure: false,
                                             typeIsBlock: true,
                                             defaultValue: nil))
        }

        fields.append(APIDefinitionField(name: "interceptor",
                                         description: "use this if you need to intercept overall requests",
                                         typeName: "NetworkInterceptor",
                                         isRequired: false,
                                         typeIsAutoclosure: false,
                                         typeIsBlock: false,
                                         defaultValue: "nil"))

        return fields
    }
}
