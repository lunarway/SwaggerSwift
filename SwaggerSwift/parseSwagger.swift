import SwaggerSwiftML

func parse(swagger: Swagger) -> ServiceDefinition {
    let result = swagger.paths
        .map { parse(path: $0.value, servicePath: $0.key, swagger: swagger) }

    let functions = result.flatMap { $0.0 }
    let definitions = result.flatMap { $0.1 }

    let builtinDefinitions = swagger.definitions!.map {
        getType(forSchema: $0.value, typeNamePrefix: $0.key, swagger: swagger).1
    }.flatMap { $0 }

    let defaultFields = [
        ServiceField(name: "urlSession", typeName: "URLSession"),
        ServiceField(name: "baseUrl", typeName: "String")
    ]

    return ServiceDefinition(typeName: swagger.serviceName, fields: defaultFields, functions: functions, innerTypes: definitions + builtinDefinitions)
}
