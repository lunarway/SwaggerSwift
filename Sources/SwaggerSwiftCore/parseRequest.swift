import SwaggerSwiftML

func parse(request requestNode: Node<Response>, httpMethod: HTTPMethod, servicePath: String, statusCode: Int, swagger: Swagger) -> (TypeType, [ModelDefinition]) {
    let prefix = "\(servicePath.replacingOccurrences(of: "{", with: "").replacingOccurrences(of: "}", with: "").components(separatedBy: "/").map { $0.components(separatedBy: "-") }.flatMap { $0 }.map { $0.uppercasingFirst }.joined().capitalizingFirstLetter())\(statusCode)"

    let request: Response
    switch requestNode {
    case .reference(let ref):
		let pathParts = ref.split(separator: "/").map { String($0) }
		guard pathParts.count == 3 else { fatalError( "Invalid reference found: \(ref)" ) }

		let pathType = pathParts[1].lowercased()
		let typeName = pathParts[2]

		switch pathType {
		case "definitions":
			guard let schema = swagger.definitions?[typeName] else {
				fatalError("\(swagger.serviceName): Failed to find referenced object: \(ref)")
			}

			request = Response(schema: schema)
		case "responses":
			guard let req = swagger.responses?[typeName] else {
				fatalError("\(swagger.serviceName): Failed to find referenced object: \(ref)")
			}

			request = req
		default:
			fatalError("\(swagger.serviceName): Unsupported path ('\(pathType)') provided in reference: '\(ref)'")
		}
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
