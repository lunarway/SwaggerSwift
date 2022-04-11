import SwaggerSwiftML

func getType(forSchema schema: SwaggerSwiftML.Schema, typeNamePrefix: String, swagger: Swagger) -> (TypeType, [ModelDefinition]) {
    switch schema.type {
    case .string(let format, let enumValues, _, _, _):
        if let enumValues = enumValues {
            let enumTypename = typeNamePrefix.modelNamed
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
                log("⚠️ \(swagger.serviceName): A string should not be defined to be a \(format)", error: true)
                return (.object(typeName: "String"), [])
            case .unsupported(let unsupported):
                switch unsupported {
                case "ISO8601":
                    return (.date, [])
                case "uuid":
                    return (.object(typeName: "String"), [])
                case "datetime":
                    return (.object(typeName: "Date"), [])
                case "uri":
                    return (.object(typeName: "URL"), [])
                default:
                    log("⚠️ \(swagger.serviceName): SwaggerSwift does not support '\(unsupported)' for strings", error: true)
                    return (.object(typeName: "String"), [])
                }
            }
        } else {
            return (.string, [])
        }
    case .integer(let format, _, _, _, _, _):
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
                log("⚠️ \(swagger.serviceName): SwaggerSwift does not support '\(format)' for ints", error: true)
                return (.int, [])
            case .unsupported(let unsupported):
                switch unsupported {
                case "int":
                    return (.int, [])
                case "int64":
                    return (.int64, [])
                case "decimal":
                    return (.double, [])
                default:
                    log("⚠️ \(swagger.serviceName): SwaggerSwift does not support '\(unsupported)' for ints", error: true)
                    return (.int, [])
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
                log("⚠️ \(swagger.serviceName): SwaggerSwift does not support '\(format)' for number", error: true)
                return (.double, [])
            case .unsupported(let unsupported):
                switch unsupported {
                case "int", "integer":
                    return (.int, [])
                case "int64":
                    return (.int64, [])
                case "float64":
                    log("⚠️ \(swagger.serviceName): `format: float64` format does not exist for type number in the Swagger spec. Please change it to specify `format: double` instead.", error: true)
                    return (.double, [])
                case "decimal":
                    return (.double, [])
                default:
                    log("⚠️ \(swagger.serviceName): SwaggerSwift does not support '\(unsupported)' for number", error: true)
                    return (.double, [])
                }
            }
        }

        return (.double, [])
    case .boolean(let defaultValue):
        return (.boolean(defaultValue: defaultValue), [])
    case .array(let items, _, _, _, _):
        let (type, inlineModels) = typeOfItems(schema: schema,
                                               items: items,
                                               typeNamePrefix: "\(typeNamePrefix)Item",
                                               swagger: swagger)

        return (.array(typeName: type), inlineModels)
    case .object(let properties, let allOf):
        return ObjectModelFactory().make(
            properties: properties,
            requiredProperties: [],
            allOf: allOf,
            swagger: swagger,
            typeNamePrefix: typeNamePrefix,
            schema: schema,
            customFields: [:]
        )
    case .dictionary(let valueType, _):
        switch valueType {
        case .any:
            return (.object(typeName: "[String: AdditionalProperty]"), [])
        case .reference(let reference):
            guard let modelReference = ModelReference(rawValue: reference) else {
                return (.void, [])
            }

            return (.object(typeName: "[String: " + modelReference.typeName + "]"), [])
        case .schema(let schema):
            let (type, inlineDefinitions) = getType(forSchema: schema,
                                                    typeNamePrefix: typeNamePrefix,
                                                    swagger: swagger)
            let valueString = type.toString(required: true)
            return (.object(typeName: "[String: " + valueString + "]"), inlineDefinitions)
        }
    case .file:
        return (.void, [])
    case .freeform:
        return (.object(typeName: "[String: AdditionalProperty]"), [])
    }
}

private func typeOfItems(schema: Schema, items: Node<Items>, typeNamePrefix: String, swagger: Swagger) -> (TypeType, [ModelDefinition]) {
    switch items {
    case .reference(let reference):
        guard let schema = swagger.findSchema(reference: reference) else {
            log("[\(swagger.serviceName)] Failed to find definition named: \(reference)", error: true)
            return (.void, [])
        }

        switch schema.type {
        case .object:
            if let typeName = ModelReference(rawValue: reference)?.typeName {
                return (.object(typeName: typeName), [])
            } else {
                log("[\(swagger.serviceName)] Invalid reference found: \(reference)", error: true)
                return (.void, [])
            }
        case .string:
            return (.string, [])
        default:
            log("[\(swagger.serviceName)] Unsupported schema type: \(schema.type)")
            return (.void, [])
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
            return (.boolean(defaultValue: nil), [])
        case .array(let items, collectionFormat: _, maxItems: _, minItems: _, uniqueItems: _):
            return typeOfItems(schema: schema, items: Node.node(items), typeNamePrefix: typeNamePrefix, swagger: swagger)
        case .object(let required, let properties, let allOf):
            return ObjectModelFactory().make(
                properties: properties,
                requiredProperties: required,
                allOf: allOf,
                swagger: swagger,
                typeNamePrefix: typeNamePrefix,
                schema: schema,
                customFields: node.customFields
            )
        }
    }
}
