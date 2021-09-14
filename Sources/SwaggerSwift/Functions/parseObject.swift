import SwaggerSwiftML

func parseObject(required: [String], properties: [String: Node<Schema>], allOf: [Node<Schema>]?, swagger: Swagger, typeNamePrefix: String, schema: Schema, customFields: [String: String]) -> (TypeType, [ModelDefinition]) {
    let typeName = (customFields["x-override-name"] ?? schema.overridesName ?? typeNamePrefix).uppercasingFirst

    if let allOf = allOf {
        let result: [(String?, [ModelField], [ModelDefinition])] = allOf.map {
            switch $0 {
            case .reference(let reference):
                let node = swagger.findSchema(node: .reference(reference))
                if case SchemaType.object = node.type {
                    let typeName = reference.components(separatedBy: "/").last ?? ""
                    return (typeName, [], [])
                } else {
                    let result = getType(forSchema: node, typeNamePrefix: typeName, swagger: swagger)
                    return (nil, [], result.1)
                }
            case .node(let innerSchema):
                if case let SchemaType.object(properties, allOf) = innerSchema.type {
                    assert(allOf == nil, "Not implemented")
                    let result: [(ModelField, [ModelDefinition])] = properties.map {
                        switch $0.value {
                        case .reference(let reference):
                            let node = swagger.findSchema(node: .reference(reference))
                            let typeName = reference.components(separatedBy: "/").last ?? ""
                            if case SchemaType.object = node.type {
                                return (ModelField(description: node.description, type: .object(typeName: typeName), name: $0.key, required: innerSchema.required.contains($0.key)), [])
                            } else {
                                let type = getType(forSchema: node, typeNamePrefix: typeName, swagger: swagger)
                                return (ModelField(description: node.description, type: type.0, name: $0.key, required: innerSchema.required.contains($0.key)), type.1)
                            }
                        case .node(let schema):
                            let type = getType(forSchema: schema, typeNamePrefix: typeName, swagger: swagger)
                            return (ModelField(description: schema.description, type: type.0, name: $0.key, required: innerSchema.required.contains($0.key)), type.1)
                        }
                    }

                    return (nil, result.map { $0.0 }, result.flatMap { $0.1 })
                } else {
                    fatalError("Not implemented")
                }
            }
        }

        let models = result.flatMap { $0.2 }

        let model = Model(description: schema.description,
                          typeName: typeName,
                          fields: result.flatMap { $0.1 },
                          inheritsFrom: ["Codable"],
                          isInternalOnly: schema.isInternalOnly,
                          embeddedDefinitions: models)

        return (.object(typeName: typeName), [.model(model)])
    }

    // when parsing the properties (fields) of a schema, there can be embedded models associated with the field
    let fieldsAndEmbeddedTypes: [(ModelField, [ModelDefinition])] = properties.map { property in
        let propertyName = property.key
        let schemaNode = property.value

        switch schemaNode {
        case .reference(let reference):
            let node = swagger.findSchema(node: .reference(reference))
            var typeName = reference.components(separatedBy: "/").last ?? ""
            typeName = "\(typeName.uppercasingFirst)"
            if typeName == "Type" {
                typeName = "\(typeName)\(propertyName.uppercasingFirst)"
            }

            if case SchemaType.object = node.type {
                return (ModelField(description: node.description,
                                   type: .object(typeName: typeName),
                                   name: propertyName,
                                   required: schema.required.contains(propertyName)), [])
            } else {
                let (type, embeddedDefinitions) = getType(forSchema: node, typeNamePrefix: typeName, swagger: swagger)
                return (ModelField(description: node.description,
                                   type: type,
                                   name: propertyName,
                                   required: schema.required.contains(propertyName)), embeddedDefinitions)
            }
        case .node(let innerSchema):
            var typeName = "\(propertyName.uppercasingFirst)"
            if typeName == "Type" {
                typeName = "\(typeName)\(propertyName.uppercasingFirst)"
            }

            let (type, embeddedDefinitions) = getType(forSchema: innerSchema,
                                                      typeNamePrefix: typeName,
                                                      swagger: swagger)

            let modelField = ModelField(description: innerSchema.description,
                                        type: type,
                                        name: propertyName,
                                        required: required.contains(propertyName) || schema.required.contains(propertyName))

            return (modelField, embeddedDefinitions)
        }
    }

    let fields = fieldsAndEmbeddedTypes.map { $0.0 }
    let embeddedModelDefinitions = fieldsAndEmbeddedTypes.flatMap { $0.1 }

    let model = Model(description: schema.description,
                      typeName: typeName,
                      fields: fields.sorted(by: { $0.safePropertyName < $1.safePropertyName }),
                      inheritsFrom: ["Codable"],
                      isInternalOnly: schema.isInternalOnly,
                      embeddedDefinitions: embeddedModelDefinitions)

    return (.object(typeName: typeName), [.model(model)])
}
