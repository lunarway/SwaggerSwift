import SwaggerSwiftML

func parse(request requestNode: Node<Response>, httpMethod: HTTPMethod, servicePath: String, statusCode: Int, swagger: Swagger) -> (TypeType, [ModelDefinition]) {
    let prefix = "\(servicePath.replacingOccurrences(of: "{", with: "").replacingOccurrences(of: "}", with: "").components(separatedBy: "/").map { $0.components(separatedBy: "-") }.flatMap { $0 }.map { $0.uppercasingFirst }.joined().capitalizingFirstLetter())\(statusCode)"

    let request: Response
    switch requestNode {
    case .reference(let ref):
        let str = String(ref.split(separator: "/").last!)
        request = swagger.responses![str]!
    case .node(let node):
        request = node
    }

    if let schemaNode = request.schema {
        switch schemaNode {
        case .node(let schema):
            return getType(forSchema: schema, typeNamePrefix: prefix, swagger: swagger)
        case .reference(let ref):
            let schema = swagger.findSchema(node: .reference(ref))
            let typeName = (ref.components(separatedBy: "/").last ?? "").uppercasingFirst

            if case SchemaType.object = schema.type {
                return (.object(typeName: typeName), [])
            } else {
                return getType(forSchema: schema, typeNamePrefix: prefix, swagger: swagger)
            }
        }
    } else {
        return (.void, [])
    }
}
