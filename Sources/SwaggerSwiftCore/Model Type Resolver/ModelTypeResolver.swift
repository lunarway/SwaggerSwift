import SwaggerSwiftML

public struct ModelTypeResolver {
    let objectModelFactory: ObjectModelFactory
    public init(objectModelFactory: ObjectModelFactory) {
        self.objectModelFactory = objectModelFactory
    }

    struct ResolvedModel {
        let propertyType: TypeType
        let inlineModelDefinitions: [ModelDefinition]

        init(_ propertyType: TypeType, _ inlineModelDefinitions: [ModelDefinition] = []) {
            self.propertyType = propertyType
            self.inlineModelDefinitions = inlineModelDefinitions
        }
    }

    /// Resolves the entire model tree of a Swagger schema
    /// - Parameters:
    ///   - schema: the schema that should be resolved
    ///   - typeNamePrefix: a type prefix that can be used as a type name if nothing else is present
    ///   - namespace: the namespace of any inline type
    ///   - swagger: the swagger spec
    /// - Returns:the resolved models
    func resolve(forSchema schema: SwaggerSwiftML.Schema, typeNamePrefix: String, namespace: String, swagger: Swagger) -> ResolvedModel {
        switch schema.type {
        case .string(let format, let enumValues, _, _, _):
            if let enumValues = enumValues {
                let enumTypename = typeNamePrefix.modelNamed

                let model = ModelDefinition.enumeration(Enumeration(serviceName: swagger.serviceName,
                                                                    description: schema.description,
                                                                    typeName: enumTypename,
                                                                    values: enumValues,
                                                                    isCodable: true))

                return ResolvedModel(.enumeration(typeName: enumTypename), [model])
            }

            if let format = format {
                switch format {
                case .string:
                    return .init(.string)
                case .date:
                    return .init(.object(typeName: "Date"))
                case .dateTime:
                    return .init(.object(typeName: "Date"))
                case .password:
                    return .init(.string)
                case .email:
                    return .init(.string)
                case .binary:
                    return .init(.object(typeName: "Data"))
                case .long: fallthrough
                case .float: fallthrough
                case .double: fallthrough
                case .byte: fallthrough
                case .boolean: fallthrough
                case .int32:
                    log("⚠️ \(swagger.serviceName): A string should not be defined to be a \(format)", error: true)
                    return .init(.object(typeName: "String"))
                case .unsupported(let unsupported):
                    switch unsupported {
                    case "ISO8601":
                        return .init(.date, [])
                    case "uuid":
                        return .init(.object(typeName: "String"))
                    case "datetime":
                        return .init(.object(typeName: "Date"))
                    case "uri":
                        return .init(.object(typeName: "URL"))
                    default:
                        log("⚠️ \(swagger.serviceName): SwaggerSwift does not support '\(unsupported)' for strings", error: true)
                        return .init(.object(typeName: "String"))
                    }
                }
            } else {
                return .init(.string, [])
            }
        case .integer(let format, _, _, _, _, _):
            if let format = format {
                switch format {
                case .long:
                    return .init(.double)
                case .float:
                    return .init(.float)
                case .int32:
                    return .init(.int)
                case .double:
                    return .init(.double)
                case .date: fallthrough
                case .dateTime: fallthrough
                case .password: fallthrough
                case .email: fallthrough
                case .string: fallthrough
                case .byte: fallthrough
                case .binary: fallthrough
                case .boolean:
                    log("⚠️ \(swagger.serviceName): SwaggerSwift does not support '\(format)' for integer type", error: true)
                    return .init(.int)
                case .unsupported(let unsupported):
                    switch unsupported {
                    case "int":
                        return .init(.int)
                    case "int64":
                        return .init(.int64)
                    case "decimal":
                        return .init(.double)
                    default:
                        log("⚠️ \(swagger.serviceName): SwaggerSwift does not support '\(unsupported)' for integer type. Use ", error: true)
                        return .init(.int)
                    }
                }
            }

            return .init(.int)
        case .number(let format, _, _, _, _, _):
            if let format = format {
                switch format {
                case .long:
                    return .init(.double)
                case .float:
                    return .init(.float)
                case .int32:
                    return .init(.int)
                case .double:
                    return .init(.double)
                case .date: fallthrough
                case .dateTime: fallthrough
                case .password: fallthrough
                case .email: fallthrough
                case .string: fallthrough
                case .byte: fallthrough
                case .binary: fallthrough
                case .boolean:
                    log("⚠️ \(swagger.serviceName): SwaggerSwift does not support '\(format)' for number", error: true)
                    return .init(.double)
                case .unsupported(let unsupported):
                    switch unsupported {
                    case "int", "integer":
                        return .init(.int)
                    case "int64":
                        return .init(.int64)
                    case "float64":
                        log("⚠️ \(swagger.serviceName): `format: float64` format does not exist for type number in the Swagger spec. Please change it to specify `format: double` instead.", error: true)
                        return .init(.double)
                    case "decimal":
                        return .init(.double)
                    default:
                        log("⚠️ \(swagger.serviceName): SwaggerSwift does not support '\(unsupported)' for number", error: true)
                        return .init(.double)
                    }
                }
            }

            return .init(.double)
        case .boolean(let defaultValue):
            return .init(.boolean(defaultValue: defaultValue))
        case .array(let items, _, _, _, _):
            let (type, inlineModels) = typeOfItems(schema: schema,
                                                   items: items,
                                                   typeNamePrefix: "\(typeNamePrefix)Item",
                                                   namespace: namespace,
                                                   swagger: swagger)

            return .init(.array(typeName: type), inlineModels)
        case .object(let properties, let allOf):
            let resolvedType = objectModelFactory.make(properties: properties,
                                                       requiredProperties: [],
                                                       allOf: allOf,
                                                       swagger: swagger,
                                                       typeNamePrefix: typeNamePrefix,
                                                       schema: schema,
                                                       namespace: namespace,
                                                       customFields: [:])
            return .init(resolvedType.0, resolvedType.1)
        case .dictionary(let valueType, _):
            switch valueType {
            case .any:
                return .init(.object(typeName: "[String: AdditionalProperty]"))
            case .reference(let reference):
                guard let modelReference = ModelReference(rawValue: reference) else {
                    return .init(.void)
                }

                return .init(.object(typeName: "[String: " + modelReference.typeName + "]"))
            case .schema(let schema):
                let resolvedType = self.resolve(forSchema: schema,
                                                typeNamePrefix: typeNamePrefix,
                                                namespace: namespace,
                                                swagger: swagger)
                let valueString = resolvedType.propertyType.toString(required: true)
                return .init(.object(typeName: "[String: " + valueString + "]"), resolvedType.inlineModelDefinitions)
            }
        case .file:
            return .init(.void)
        case .freeform:
            return .init(.object(typeName: "[String: AdditionalProperty]"), [.array(.init(description: schema.description, typeName: typeNamePrefix, containsType: "String: AdditionalProperty"))])
        }
    }

    private func typeOfItems(schema: Schema, items: Node<Items>, typeNamePrefix: String, namespace: String, swagger: Swagger) -> (TypeType, [ModelDefinition]) {
        switch items {
        case .reference(let reference):
            guard let schema = swagger.findSchema(reference: reference) else {
                log("[\(swagger.serviceName)] Could not resolve reference: \(reference) - are you sure it exists?", error: true)
                return (.void, [])
            }

            switch schema.type {
            case .object:
                if let typeName = ModelReference(rawValue: reference)?.typeName {
                    return (.object(typeName: swagger.serviceName + "." + typeName), [])
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
            case .number(let format, maximum: _, exclusiveMaximum: _, minimum: _, exclusiveMinimum: _, multipleOf: _):
                if let format = format {
                    switch format {
                    case .int32:
                        return (TypeType.int, [])
                    case .long:
                        return (TypeType.int64, [])
                    case .float:
                        return (TypeType.float, [])
                    case .double:
                        return (TypeType.double, [])
                    case .string: fallthrough
                    case .byte: fallthrough
                    case .binary: fallthrough
                    case .boolean: fallthrough
                    case .date: fallthrough
                    case .dateTime: fallthrough
                    case .password: fallthrough
                    case .email: fallthrough
                    case .unsupported:
                        log("[\(swagger.serviceName)] Unsupported schema type: \(format)")
                        return (.void, [])
                    }
                } else {
                    return (.int, [])
                }
            case .integer(format: _, maximum: _, exclusiveMaximum: _, minimum: _, exclusiveMinimum: _, multipleOf: _):
                return (.int, [])
            case .boolean:
                return (.boolean(defaultValue: nil), [])
            case .array(let items, collectionFormat: _, maxItems: _, minItems: _, uniqueItems: _):
                return typeOfItems(schema: schema,
                                   items: Node.node(items),
                                   typeNamePrefix: typeNamePrefix,
                                   namespace: namespace,
                                   swagger: swagger)
            case .object(let required, let properties, let allOf):
                return objectModelFactory.make(
                    properties: properties,
                    requiredProperties: required,
                    allOf: allOf,
                    swagger: swagger,
                    typeNamePrefix: typeNamePrefix,
                    schema: schema,
                    namespace: namespace,
                    customFields: node.customFields
                )
            }
        }
    }
}
