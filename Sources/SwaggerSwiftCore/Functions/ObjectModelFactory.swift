import SwaggerSwiftML

private struct AllOfPart {
    let typeName: String?
    let fields: [ModelField]
    let embedddedDefinitions: [ModelDefinition]
}

struct ObjectModelFactory {
    func make(properties: [String: Node<Schema>], requiredProperties: [String], allOf: [Node<Schema>]?, swagger: Swagger, typeNamePrefix: String, schema: Schema, customFields: [String: String]) -> (TypeType, [ModelDefinition]) {
        let typeName = (customFields["x-override-name"] ?? schema.overridesName ?? typeNamePrefix)
            .modelNamed
            .split(separator: ".").map { String($0).uppercasingFirst }.joined()

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
        } else {
            // when parsing the properties (fields) of a schema, there can be embedded models associated with the field
            let (properties, inlineModels) = resolveProperties(properties: properties,
                                                               withRequiredProperties: requiredProperties + schema.required,
                                                               swagger: swagger)

            let model = Model(description: schema.description,
                              typeName: typeName,
                              fields: properties.sorted(by: { $0.safePropertyName < $1.safePropertyName }),
                              inheritsFrom: [],
                              isInternalOnly: schema.isInternalOnly,
                              embeddedDefinitions: inlineModels,
                              isCodable: true)

            return (.object(typeName: typeName), [.object(model)])
        }
    }

    private func resolveProperties(properties: [String: Node<Schema>], withRequiredProperties requiredProperties: [String], swagger: Swagger) -> ([ModelField], [ModelDefinition]) {
        var totalFields = [ModelField]()
        var totalModels = [ModelDefinition]()

        for (name, schemaNode) in properties {
            if let (field, models) = resolveProperty(named: name, schemaNode: schemaNode, withRequiredProperties: requiredProperties, swagger: swagger) {
                totalFields.append(field)
                totalModels.append(contentsOf: models)
            }
        }

        return (totalFields, totalModels)
    }

    private func resolveProperty(named: String, schemaNode: Node<Schema>, withRequiredProperties requiredProperties: [String], swagger: Swagger) -> (ModelField, [ModelDefinition])? {
        let isRequired = requiredProperties.contains(named)

        switch schemaNode {
        case .reference(let reference):
            guard let schema = swagger.findSchema(reference: reference) else {
                return nil
            }

            guard let modelReference = ModelReference(rawValue: reference) else {
                return nil
            }

            let typeName: String
            if modelReference.typeName == "Type" {
                typeName = "Type\(named.uppercasingFirst)"
                    .modelNamed
                    .split(separator: ".").map { String($0).uppercasingFirst }.joined()
            } else {
                typeName = modelReference.typeName
            }

            let field: ModelField
            if case SchemaType.object = schema.type {
                field = ModelField(description: schema.description,
                                   type: .object(typeName: typeName),
                                   name: named,
                                   isRequired: isRequired)
            } else {
                // since it is a referenced object we dont care about the embedded definitions as they are parsed elsewhere
                let type = schema.type(named: typeName)
                field = ModelField(description: schema.description,
                                   type: type,
                                   name: named,
                                   isRequired: isRequired)
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
                                        isRequired: isRequired || schema.required.contains(named))
            return (modelField, embeddedDefinitions)
        }
    }

    private func parseAllOf(allOf: [Node<Schema>], typeName: String, swagger: Swagger) -> [AllOfPart] {
        return allOf.compactMap {
            switch $0 {
            case .reference(let reference):
                guard let schema = swagger.findSchema(reference: reference) else {
                    return nil
                }

                if case SchemaType.object = schema.type {
                    let typeName = reference.components(separatedBy: "/").last ?? ""
                    return .init(typeName: typeName,
                                 fields: [],
                                 embedddedDefinitions: [])
                } else {
                    // TODO: how is this even used?
                    let (_, inlineModels) = getType(forSchema: schema,
                                                    typeNamePrefix: typeName,
                                                    swagger: swagger)
                    return .init(typeName: nil,
                                 fields: [],
                                 embedddedDefinitions: inlineModels)
                }
            case .node(let schema):
                guard case let SchemaType.object(properties, allOfItems) = schema.type else {
                    fatalError("Not implemented")
                }

                if let allOfItems = allOfItems, allOfItems.count > 0 {
                    log("There is allOf items present but it is not currently supported")
                }

                let result: [(ModelField, [ModelDefinition])] = properties.compactMap {
                    let isRequired = schema.required.contains($0.key)

                    switch $0.value {
                    case .reference(let reference):
                        guard let schema = swagger.findSchema(reference: reference) else {
                            return nil
                        }

                        let typeName = reference.components(separatedBy: "/").last ?? ""
                        if case SchemaType.object = schema.type {
                            let field = ModelField(description: schema.description,
                                                   type: .object(typeName: typeName),
                                                   name: $0.key,
                                                   isRequired: isRequired)

                            return (field, [])
                        } else {
                            let (type, models) = getType(forSchema: schema,
                                                         typeNamePrefix: typeName,
                                                         swagger: swagger)
                            let field = ModelField(description: schema.description,
                                                   type: type,
                                                   name: $0.key,
                                                   isRequired: isRequired)
                            return (field, models)
                        }
                    case .node(let schema):
                        let (type, models) = getType(forSchema: schema, typeNamePrefix: typeName, swagger: swagger)
                        let field = ModelField(description: schema.description,
                                               type: type,
                                               name: $0.key,
                                               isRequired: isRequired)

                        return (field, models)
                    }
                }

                return .init(typeName: nil,
                             fields: result.map { $0.0 },
                             embedddedDefinitions: result.flatMap { $0.1 })
            }
        }
    }
}
