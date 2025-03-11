import SwaggerSwiftML

func parse(
    request requestNode: Node<SwaggerSwiftML.Response>,
    httpMethod: HTTPMethod,
    servicePath: String,
    statusCode: Int,
    swagger: Swagger,
    modelTypeResolver: ModelTypeResolver
) throws -> (TypeType, [ModelDefinition])? {
    let requestName =
        servicePath
        .replacingOccurrences(of: "{", with: "")
        .replacingOccurrences(of: "}", with: "")
        .components(separatedBy: "/")
        .map { $0.components(separatedBy: "-") }
        .flatMap { $0 }
        .map { $0.uppercasingFirst }
        .joined()
        .capitalizingFirstLetter()

    let prefix = "\(requestName)\(statusCode)"

    let request: SwaggerSwiftML.Response
    switch requestNode {
    case .reference(let reference):
        let modelReference = try ModelReference(rawValue: reference)

        switch modelReference {
        case .definitions:
            guard
                let schema = swagger.definitions?.first(where: {
                    $0.key.lowercased() == modelReference.typeName.lowercased()
                })?.value
            else {
                log(
                    "[\(swagger.serviceName) \(httpMethod) \(servicePath)] : Failed to find referenced definitions object: \(reference)",
                    error: true
                )
                return nil
            }

            request = SwaggerSwiftML.Response(schema: schema)
        case .responses:
            guard
                let responseObject = swagger.responses?.first(where: {
                    $0.key.lowercased() == modelReference.typeName.lowercased()
                })?.value
            else {
                log(
                    "[\(swagger.serviceName) \(httpMethod) \(servicePath)]: Failed to find referenced response object: \(reference)",
                    error: true
                )
                return nil
            }

            request = responseObject
        }
    case .node(let node):
        request = node
    }

    if let schemaNode = request.schema {
        switch schemaNode {
        case .node(let schema):
            let resolvedType = try modelTypeResolver.resolve(
                forSchema: schema,
                typeNamePrefix: prefix,
                namespace: swagger.serviceName,
                swagger: swagger
            )
            return (resolvedType.propertyType, resolvedType.inlineModelDefinitions)
        case .reference(let ref):
            let schema = try swagger.findSchema(reference: ref)
            let modelReference = try ModelReference(rawValue: ref)

            let resolvedType = schema.type(named: modelReference.typeName)

            if case .array = resolvedType {
                return (TypeType.object(typeName: modelReference.typeName), [])
            } else {
                return (resolvedType, [])
            }
        }
    } else {
        return (.void, [])
    }
}
