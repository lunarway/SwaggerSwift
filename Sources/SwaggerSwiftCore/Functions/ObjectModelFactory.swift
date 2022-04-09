import SwaggerSwiftML

private struct AllOfPart {
    let typeName: String?
    let fields: [ModelField]
    let embedddedDefinitions: [ModelDefinition]
}

struct ObjectModelFactory {
    private func resolveProperty(named: String, schemaNode: Node<Schema>, withRequiredProperties requiredProperties: [String], swagger: Swagger) -> (ModelField, [ModelDefinition]) {
        let isRequired = requiredProperties.contains(named)

        switch schemaNode {
        case .reference(let reference):
            let schema = swagger.findSchema(node: .reference(reference))
            var typeName = reference.components(separatedBy: "/").last ?? ""
            typeName = "\(typeName.uppercasingFirst)"
            if typeName == "Type" {
                typeName = "\(typeName)\(named.uppercasingFirst)"
            }

            typeName = typeName.modelNamed

            let field: ModelField
            if case SchemaType.object = schema.type {
                field = ModelField(description: schema.description,
                                   type: .object(typeName: typeName),
                                   name: named,
                                   required: isRequired)
            } else {
                // since it is a referenced object we dont care about the embedded definitions as they are parsed elsewhere
                let (type, _) = getType(forSchema: schema, typeNamePrefix: typeName, swagger: swagger)
                field = ModelField(description: schema.description,
                                       type: type,
                                       name: named,
                                       required: isRequired)

            }

            return (field, [])
        case .node(let schema):
            var fieldTypeName = "\(named.uppercasingFirst)"
            if fieldTypeName == "Type" {
                fieldTypeName = "\(fieldTypeName)\(named.uppercasingFirst)"
            }

            fieldTypeName = fieldTypeName.modelNamed

            let (type, embeddedDefinitions) = getType(forSchema: schema,
                                                      typeNamePrefix: fieldTypeName,
                                                      swagger: swagger)

            let modelField = ModelField(description: schema.description,
                                        type: type,
                                        name: named,
                                        required: isRequired || schema.required.contains(named))
            return (modelField, embeddedDefinitions)
        }
    }

    private func resolveProperties(properties: [String: Node<Schema>], withRequiredProperties requiredProperties: [String], swagger: Swagger) -> ([ModelField], [ModelDefinition]) {
        var totalFields = [ModelField]()
        var totalModels = [ModelDefinition]()

        for (name, schemaNode) in properties {
            let (field, models) = resolveProperty(named: name, schemaNode: schemaNode, withRequiredProperties: requiredProperties, swagger: swagger)
            totalFields.append(field)
            totalModels.append(contentsOf: models)
        }

        return (totalFields, totalModels)
    }

    func make(properties: [String: Node<Schema>], requiredProperties: [String], allOf: [Node<Schema>]?, swagger: Swagger, typeNamePrefix: String, schema: Schema, customFields: [String: String]) -> (TypeType, [ModelDefinition]) {
        let typeName = (customFields["x-override-name"] ?? schema.overridesName ?? typeNamePrefix).modelNamed

        if let allOf = allOf, allOf.count > 0 {
            let allOfParts: [AllOfPart] = parseAllOf(allOf: allOf, typeName: typeName, swagger: swagger)
            let embedddedDefinitions = allOfParts.flatMap { $0.embedddedDefinitions }
            let inherits = allOfParts.compactMap { $0.typeName }

            let model = Model(description: schema.description,
                              typeName: typeName,
                              fields: allOfParts.flatMap { $0.fields },
                              inheritsFrom: inherits,
                              isInternalOnly: schema.isInternalOnly,
                              embeddedDefinitions: embedddedDefinitions,
                              isCodable: true)

            return (.object(typeName: typeName), [.object(model)])
        }

        // when parsing the properties (fields) of a schema, there can be embedded models associated with the field
        let (properties, inlineModels) = resolveProperties(properties: properties, withRequiredProperties: requiredProperties, swagger: swagger)

        let model = Model(description: schema.description,
                          typeName: typeName,
                          fields: properties.sorted(by: { $0.safePropertyName < $1.safePropertyName }),
                          inheritsFrom: [],
                          isInternalOnly: schema.isInternalOnly,
                          embeddedDefinitions: inlineModels,
                          isCodable: true)

        return (.object(typeName: typeName), [.object(model)])
    }

    private func parseAllOf(allOf: [Node<Schema>], typeName: String, swagger: Swagger) -> [AllOfPart] {
        return allOf.map {
            switch $0 {
            case .reference(let reference):
                let node = swagger.findSchema(node: .reference(reference))
                if case SchemaType.object = node.type {
                    let typeName = reference.components(separatedBy: "/").last ?? ""
                    return .init(typeName: typeName,
                                 fields: [],
                                 embedddedDefinitions: [])
                } else {
                    let result = getType(forSchema: node, typeNamePrefix: typeName, swagger: swagger)
                    return .init(typeName: nil,
                                 fields: [],
                                 embedddedDefinitions: result.1)
                }
            case .node(let innerSchema):
                if case let SchemaType.object(properties, allOfItems) = innerSchema.type {
                    if let allOfItems = allOfItems, allOfItems.count > 0 {
                        log("There allOf items present but it is not currently supported")
                    }

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

                    return .init(typeName: nil,
                                 fields: result.map { $0.0 },
                                 embedddedDefinitions: result.flatMap { $0.1 })
                } else {
                    fatalError("Not implemented")
                }
            }
        }
    }
}
