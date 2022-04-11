import SwaggerSwiftML

func parse(request requestNode: Node<SwaggerSwiftML.Response>, httpMethod: HTTPMethod, servicePath: String, statusCode: Int, swagger: Swagger) -> (TypeType, [ModelDefinition])? {
    let requestName = servicePath
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
        guard let modelReference = ModelReference(rawValue: reference) else {
            log("[\(swagger.serviceName) \(httpMethod) \(servicePath)]: Failed to parse reference: \(reference)")
            return nil
        }

        switch modelReference {
        case .definitions:
            guard let schema = swagger.definitions?[modelReference.typeName] else {
				fatalError("\(swagger.serviceName): Failed to find referenced object: \(reference)")
			}

            request = SwaggerSwiftML.Response(schema: schema)
        case .responses:
			guard let req = swagger.responses?[modelReference.typeName] else {
				fatalError("\(swagger.serviceName): Failed to find referenced object: \(reference)")
			}

			request = req
		}
    case .node(let node):
        request = node
    }

    if let schemaNode = request.schema {
        switch schemaNode {
        case .node(let schema):
            let (type, embeddedDefinitions) = getType(forSchema: schema,
                                                      typeNamePrefix: prefix,
                                                      swagger: swagger)
            return (type, embeddedDefinitions)
        case .reference(let ref):
            guard let schema = swagger.findSchema(reference: ref) else {
                log("[\(swagger.serviceName) \(httpMethod) \(servicePath)] Failed to find definition named: \(ref)", error: true)
                return nil
            }

            guard let modelReference = ModelReference(rawValue: ref) else {
                return nil
            }

            return (schema.type(named: modelReference.typeName), [])
        }
    } else {
        return (.void, [])
    }
}

extension Schema {
    /// Provides the `TypeType` for a schema - this is different from `getType` is in it doesnt parse the schema tree
    /// - Parameter name: the name of the type
    func type(named name: String) -> TypeType {
        switch self.type {
        case .string(_, let enumValues, _, _, _):
            if let enumValues = enumValues, enumValues.count > 0 {
                return TypeType.object(typeName: name)
            } else {
                return TypeType.string
            }
        case .number:
            return .int
        case .integer:
            return .int
        case .boolean(let defaultValue):
            return .boolean(defaultValue: defaultValue)
        case .array:
            return .array(typeName: .object(typeName: name))
        case .object:
            return .object(typeName: name)
        case .freeform:
            return .object(typeName: name)
        case .file:
            return .object(typeName: name)
        case .dictionary:
            return .object(typeName: name)
        }
    }
}
