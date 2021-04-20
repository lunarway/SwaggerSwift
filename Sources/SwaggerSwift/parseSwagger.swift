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

    let hasGlobalHeaders = (swaggerFile.globalHeaders ?? []).count > 0

    var serviceFields = [
        ServiceField(name: "urlSession",
                     description: "the underlying URLSession. This defaults to the standard `.shared` is none is specified",
                     typeName: "URLSession",
                     required: true,
                     typeIsAutoclosure: false,
                     typeIsBlock: false,
                     defaultValue: ".shared"),
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
                             innerTypes: resolvedBuiltinModels + resolvedDefinitions)
}
