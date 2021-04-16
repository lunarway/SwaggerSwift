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
        ServiceField(name: "urlSession", typeName: "URLSession", typeIsBlock: false),
        ServiceField(name: "baseUrl", typeName: "String", typeIsBlock: false),
    ]

    if hasGlobalHeaders {
        serviceFields.append(ServiceField(name: "headerProvider", typeName: "() -> GlobalHeaders", typeIsBlock: true))
    }

    serviceFields.append(ServiceField(name: "interceptor", typeName: "NetworkInterceptor?", typeIsBlock: false))

    let builtInModels = builtinDefinitions.compactMap { model -> Model? in
        if case let ModelDefinition.model(model) = model {
            return model
        } else {
            return nil
        }
    }

    let resolvedBuiltinModels = builtinDefinitions.map { $0.resolveInherits(builtInModels) }
    let resolvedDefinitions = definitions.map { $0.resolveInherits(builtInModels) }

    return ServiceDefinition(typeName: swagger.serviceName, fields: serviceFields, functions: functions, innerTypes: resolvedBuiltinModels + resolvedDefinitions)
}
