import SwaggerSwiftML

func parse(request: SwaggerSwiftML.RequestResponse, httpMethod: HTTPMethod, servicePath: String, statusCode: Int, swagger: Swagger) -> (TypeType, [ModelDefinition]) {
    let prefix = "\(servicePath.replacingOccurrences(of: "{", with: "").replacingOccurrences(of: "}", with: "").components(separatedBy: "/").map { $0.capitalizingFirstLetter() }.joined().capitalizingFirstLetter())\(statusCode)"

    if let schemaNode = request.schema {
        switch schemaNode.value {
        case .node(let schema):
            return getType(forSchema: schema, typeNamePrefix: prefix, swagger: swagger)
        case .reference(let ref):
            let schema = swagger.findSchema(node: .reference(ref))
            if case SchemaType.object = schema.type {
                return (.object(typeName: ref.components(separatedBy: "/").last ?? ""), [])
            } else {
                return getType(forSchema: schema, typeNamePrefix: prefix, swagger: swagger)
            }
        }
    } else {
        return (.void, [])
    }
}
