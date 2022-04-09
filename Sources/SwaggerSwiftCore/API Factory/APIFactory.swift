import Foundation
import SwaggerSwiftML

struct APIFactory {
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

            let (requestFunctions, inlineModelDefinitions) = try APIRequestFactory().generateRequest(
                for: operation,
                httpMethod: httpMethod,
                servicePath: servicePath,
                swagger: swagger,
                swaggerFile: swaggerFile,
                parameters: parameters
            )

            apis.append(requestFunctions)
            modelDefinitions.append(contentsOf: inlineModelDefinitions)
        }

        return (apis, modelDefinitions)
    }

    /// Get the global set of model definitions. This is the normal specified list, and not the inline definitions that are defined in e.g. path definitions and other places
    /// - Parameter swagger: the swagger
    /// - Returns: model definitions
    private func getModelDefinitions(fromSwagger swagger: Swagger) -> [ModelDefinition] {
        return swagger.definitions?.map { definition -> [ModelDefinition] in
            // we dont need the type part as it just represents the primary model definition returned from this function
            let (_, modelDefinitions) = getType(forSchema: definition.value,
                                                typeNamePrefix: definition.key,
                                                swagger: swagger)

            return modelDefinitions
        }.flatMap { $0 } ?? []
    }

    /// Get the global set of response model definitions
    /// - Parameter swagger: the swagger
    /// - Returns: the set of global response model definitions
    private func getResponseModelDefinitions(fromSwagger swagger: Swagger) -> [ModelDefinition] {
        return swagger.responses?.map { response -> [ModelDefinition] in
            guard let schema = response.value.schema else {
                if response.value.headers != nil {
                    log("SwaggerSwift does currently not support models without schema but with defined headers")
                    /// TODO: Add support for this
                    /// Example:
                    ///  RedirectResponse:
                    ///    description: Response used to redirect the client to Location
                    ///    headers:
                    ///      Location:
                    ///        type: string
                }

                return []
            }

            switch schema {
            case .reference(let reference):
                if let (typeName, typeSchema) = swagger.definitions?.first(where: { reference == "#/definitions/\($0.key)" }) {
                    // we dont need the type part as it just represents the primary model definition returned from this function
                    let (_, modelDefinitions) = getType(forSchema: typeSchema,
                                                        typeNamePrefix: typeName,
                                                        swagger: swagger)

                    return modelDefinitions
                } else {
                    log("[\(swagger.serviceName)] Failed to find definition for reference: \(reference)", error: true)
                    return []
                }
            case .node(let schema):
                // we dont need the type part as it just represents the primary model definition returned from this function
                let (_, modelDefinitions) = getType(forSchema: schema, typeNamePrefix: response.key, swagger: swagger)
                return modelDefinitions
            }
        }.flatMap { $0 } ?? []
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
                               typeIsAutoclosure: true,
                               typeIsBlock: true,
                               defaultValue: nil),
            APIDefinitionField(name: "baseUrl",
                               description: "the block provider for the baseUrl of the service. The reason this is a block is that this enables automatically updating the network layer on backend environment change.",
                               typeName: "() -> URL",
                               isRequired: true,
                               typeIsAutoclosure: true,
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
