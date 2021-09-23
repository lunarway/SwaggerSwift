import SwaggerSwiftML

func getType(forSchema schema: SwaggerSwiftML.Schema, typeNamePrefix: String, swagger: Swagger) -> (TypeType, [ModelDefinition]) {
    switch schema.type {
    case .string(format: let format, let enumValues, _, _, _):
        if let enumValues = enumValues {
            let enumTypename = typeNamePrefix
            let def = ModelDefinition.enumeration(Enumeration(serviceName: swagger.serviceName,
                                                              description: schema.description,
                                                              typeName: enumTypename,
                                                              values: enumValues,
                                                              isCodable: true))
            return (.object(typeName: enumTypename), [def])
        }

        if let format = format {
            switch format {
            case .string:
                return (.string, [])
            case .date:
                return (.object(typeName: "Date"), [])
            case .dateTime:
                return (.object(typeName: "Date"), [])
            case .password:
                return (.string, [])
            case .email:
                return (.string, [])
            case .binary:
                return (.object(typeName: "Data"), [])
            case .long: fallthrough
            case .float: fallthrough
            case .double: fallthrough
            case .byte: fallthrough
            case .boolean: fallthrough
            case .int32:
                fatalError("Found unsupported field")
            case .unsupported(let unsupported):
                switch unsupported {
                case "ISO8601":
                    return (.date, [])
                case "uuid":
                    return (.object(typeName: "String"), [])
                case "datetime":
                    return (.object(typeName: "Date"), [])
                default:
                    fatalError("Found unsupported field: \(unsupported)")
                }
            }
        } else {
            return (.string, [])
        }
    case .integer(let format,_,_,_,_,_):
        if let format = format {
            switch format {
            case .long:
                return (.double, [])
            case .float: return (.float, [])
            case .int32: return (.int, [])
            case .double: return (.double, [])
            case .date: fallthrough
            case .dateTime: fallthrough
            case .password: fallthrough
            case .email: fallthrough
            case .string: fallthrough
            case .byte: fallthrough
            case .binary: fallthrough
            case .boolean:
                fatalError("This cannot happen for this case")
            case .unsupported(let unsupported):
                switch unsupported {
                case "int":
                    return (.int, [])
                case "int64":
                    return (.int64, [])
                case "decimal":
                    return (.double, [])
                default:
                    fatalError("Unsupported field type received: \(unsupported)")
                }
            }
        }

        return (.int, [])
    case .number(let format, _, _, _, _, _):
        if let format = format {
            switch format {
            case .long:
                return (.double, [])
            case .float: return (.float, [])
            case .int32: return (.int, [])
            case .double: return (.double, [])
            case .date: fallthrough
            case .dateTime: fallthrough
            case .password: fallthrough
            case .email: fallthrough
            case .string: fallthrough
            case .byte: fallthrough
            case .binary: fallthrough
            case .boolean:
                fatalError("This cannot happen for this case")
            case .unsupported(let unsupported):
                switch unsupported {
                case "int", "integer":
                    return (.int, [])
                case "int64":
                    return (.int64, [])
                case "decimal":
                    return (.double, [])
                default:
                    fatalError("Unsupported field type received: \(unsupported)")
                }
            }
        }

        return (.double, [])
    case .boolean:
        return (.boolean, [])
    case .array(let items, _, _, _, _):
        let type = typeOfItems(schema: schema,
                               items: items,
                               typeNamePrefix: "\(typeNamePrefix)Item",
                               swagger: swagger)
        return (.array(typeName: type.0), type.1)
    case .object(let properties, allOf: let allOf):
        return parseObject(required: [],
                           properties: properties,
                           allOf: allOf,
                           swagger: swagger,
                           typeNamePrefix: typeNamePrefix,
                           schema: schema,
                           customFields: [:])
    case .dictionary(valueType: let valueType, keys: _):
        switch valueType {
        case .any:
            return (.object(typeName: "[String: AdditionalProperty]"), [])
        case .reference(_):
            fatalError("not supported")
        case .schema(let schema):
            return getType(forSchema: schema,
                           typeNamePrefix: typeNamePrefix,
                           swagger: swagger)
        }
    case .file:
        return (.void, [])
    case .freeform:
        return (.object(typeName: "[String: AdditionalProperty]"), [])
    }
}

private func typeOfItems(schema: Schema, items: Node<Items>, typeNamePrefix: String, swagger: Swagger) -> (TypeType, [ModelDefinition]) {
    switch items {
    case .reference(let ref):
        let schema = swagger.findSchema(node: .reference(ref))
        if case SchemaType.object = schema.type {
            let typeName = ref.components(separatedBy: "/").last!.uppercasingFirst
            return (.object(typeName: typeName), [])
        } else {
            fatalError()
        }
    case .node(let node):
        switch node.type {
        case .string(format: _, enumValues: _, maxLength: _, minLength: _, pattern: _):
            return (.string, [])
        case .number(format: _, maximum: _, exclusiveMaximum: _, minimum: _, exclusiveMinimum: _, multipleOf: _):
            return (.int, [])
        case .integer(format: _, maximum: _, exclusiveMaximum: _, minimum: _, exclusiveMinimum: _, multipleOf: _):
            return (.int, [])
        case .boolean:
            return (.boolean, [])
        case .array(let items, collectionFormat: _, maxItems: _, minItems: _, uniqueItems: _):
            return typeOfItems(schema: schema, items: Node.node(items), typeNamePrefix: typeNamePrefix, swagger: swagger)
        case .object(required: let required, properties: let properties, allOf: let allOf):
            return parseObject(required: required,
                               properties: properties,
                               allOf: allOf,
                               swagger: swagger,
                               typeNamePrefix: typeNamePrefix,
                               schema: schema,
                               customFields: node.customFields)
        }
    }
}
