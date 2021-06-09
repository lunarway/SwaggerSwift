import Foundation
import SwaggerSwiftML

func parse(swagger: Swagger, swaggerFile: SwaggerFile) -> ServiceDefinition {
    let result = swagger.paths
        .map { parse(path: $0.value, servicePath: $0.key, swagger: swagger, swaggerFile: swaggerFile) }

    let functions = result.flatMap { $0.0 }
    let definitions = result.flatMap { $0.1 }

    let builtinDefinitions = swagger.definitions!.map {
        getType(forSchema: $0.value, typeNamePrefix: $0.key, swagger: swagger).1
    }.flatMap { $0 }

    let builtInResponses: [ModelDefinition] = swagger.responses?.map { response -> [ModelDefinition] in
        switch response.value.schema! {
        case .reference(let reference):
            if let definition = swagger.definitions?.first(where: { reference == "#/definitions/\($0.key)" }) {
                return getType(forSchema: definition.value, typeNamePrefix: response.key, swagger: swagger).1
            } else {
                fatalError("Failed to find definition with reference: \(reference)")
            }
        case .node(let schema):
            return getType(forSchema: schema, typeNamePrefix: response.key, swagger: swagger).1
        }
    }.flatMap { $0 } ?? []

    let hasGlobalHeaders = (swaggerFile.globalHeaders ?? []).count > 0

    var serviceFields = [
        ServiceField(name: "urlSession",
                     description: "the underlying URLSession. This is an autoclosure to allow updated instances to come into this instance.",
                     typeName: "() -> URLSession",
                     required: true,
                     typeIsAutoclosure: true,
                     typeIsBlock: true,
                     defaultValue: nil),
        ServiceField(name: "baseUrl",
                     description: "the block provider for the baseUrl of the service. The reason this is a block is that this enables automatically updating the network layer on backend environment change.",
                     typeName: "() -> URL",
                     required: true,
                     typeIsAutoclosure: true,
                     typeIsBlock: true,
                     defaultValue: nil),
    ]

    if hasGlobalHeaders {
        serviceFields.append(ServiceField(name: "headerProvider",
                                          description: "a block provider for the set of globally defined headers",
                                          typeName: "() -> GlobalHeaders",
                                          required: true,
                                          typeIsAutoclosure: false,
                                          typeIsBlock: true,
                                          defaultValue: nil))
    }

    serviceFields.append(ServiceField(name: "interceptor",
                                      description: "use this if you need to intercept overall requests",
                                      typeName: "NetworkInterceptor",
                                      required: false,
                                      typeIsAutoclosure: false,
                                      typeIsBlock: false,
                                      defaultValue: "nil"))

    let builtInModels = builtinDefinitions.compactMap { model -> Model? in
        if case let ModelDefinition.model(model) = model {
            return model
        } else {
            return nil
        }
    }

    let resolvedBuiltinModels = builtinDefinitions.map { $0.resolveInherits(builtInModels) }
    let resolvedDefinitions = definitions.map { $0.resolveInherits(builtInModels) }

    return ServiceDefinition(typeName: swagger.serviceName,
                             description: swagger.info.description?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines),
                             fields: serviceFields,
                             functions: functions,
                             innerTypes: resolvedBuiltinModels + resolvedDefinitions + builtInResponses)
}
