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
    func resolve(
        forSchema schema: SwaggerSwiftML.Schema,
        typeNamePrefix: String,
        namespace: String,
        swagger: Swagger
    ) throws -> ResolvedModel {
        switch schema.type {
        case .string(let format, let enumValues, _, _, _, let defaultValue):
            let type = StringResolver.resolve(
                format: format,
                enumValues: enumValues,
                typeNamePrefix: typeNamePrefix,
                defaultValue: defaultValue,
                serviceName: swagger.serviceName
            )

            if case .enumeration(let enumTypeName) = type {
                let model = ModelDefinition.enumeration(
                    Enumeration(
                        serviceName: swagger.serviceName,
                        description: schema.description,
                        typeName: enumTypeName,
                        values: enumValues ?? [],
                        isCodable: true,
                        collectionFormat: nil
                    )
                )
                return ResolvedModel(.enumeration(typeName: enumTypeName), [model])
            }

            return .init(type)
        case .integer(let format, _, _, _, _, _, let defaultValue):
            let type = IntegerResolver.resolve(
                serviceName: swagger.serviceName,
                format: format,
                defaultValue: defaultValue
            )

            return .init(type)

        case .number(let format, _, _, _, _, _, let defaultValue):
            let type = NumberResolver.resolve(
                format: format,
                defaultValue: defaultValue,
                serviceName: swagger.serviceName
            )

            return ResolvedModel(type)
        case .boolean(let defaultValue):
            let type = BooleanResolver.resolve(with: defaultValue)
            return .init(type)
        case .array(let items, _, _, _, _):
            let (type, inlineModels) = try typeOfItems(
                schema: schema,
                items: items,
                typeNamePrefix: "\(typeNamePrefix)Item",
                namespace: namespace,
                swagger: swagger
            )

            return .init(.array(type: type), inlineModels)
        case .object(let properties, let allOf):
            let resolvedType = try objectModelFactory.make(
                properties: properties,
                requiredProperties: [],
                allOf: allOf,
                swagger: swagger,
                typeNamePrefix: typeNamePrefix,
                schema: schema,
                namespace: namespace,
                customFields: [:]
            )
            return .init(resolvedType.0, resolvedType.1)
        case .dictionary(let valueType, _):
            switch valueType {
            case .any:
                return .init(.object(typeName: "[String: AdditionalProperty]"))
            case .reference(let reference):
                let modelReference = try ModelReference(rawValue: reference)
                return .init(.object(typeName: "[String: " + modelReference.typeName + "]"))
            case .schema(let schema):
                let resolvedType = try self.resolve(
                    forSchema: schema,
                    typeNamePrefix: typeNamePrefix,
                    namespace: namespace,
                    swagger: swagger
                )
                let valueString = resolvedType.propertyType.toString(required: true)
                return .init(
                    .object(typeName: "[String: " + valueString + "]"),
                    resolvedType.inlineModelDefinitions
                )
            }
        case .file:
            return .init(.void)
        case .freeform:
            return .init(
                .object(typeName: "[String: AdditionalProperty]"),
                [
                    .array(
                        .init(
                            description: schema.description,
                            typeName: typeNamePrefix,
                            containsType: "String: AdditionalProperty"
                        )
                    )
                ]
            )
        }
    }

    private func typeOfItems(
        schema: Schema,
        items: Node<Items>,
        typeNamePrefix: String,
        namespace: String,
        swagger: Swagger
    ) throws -> (TypeType, [ModelDefinition]) {
        switch items {
        case .reference(let reference):
            let schema = try swagger.findSchema(reference: reference)

            switch schema.type {
            case .object:
                let typeName = try ModelReference(rawValue: reference).typeName
                return (.object(typeName: swagger.serviceName + "." + typeName), [])
            case .string:
                let resolved = try resolve(
                    forSchema: schema,
                    typeNamePrefix: typeNamePrefix,
                    namespace: namespace,
                    swagger: swagger
                )
                return (resolved.propertyType, resolved.inlineModelDefinitions)
            default:
                log("[\(swagger.serviceName)] Unsupported schema type: \(schema.type)")
                return (.void, [])
            }
        case .node(let node):
            switch node.type {
            case .string(let format, let enumValues, _, _, _):
                let type = StringResolver.resolve(
                    format: format,
                    enumValues: enumValues,
                    typeNamePrefix: typeNamePrefix,
                    defaultValue: nil,
                    serviceName: swagger.serviceName
                )

                if case .enumeration(let enumTypeName) = type {
                    let model = ModelDefinition.enumeration(
                        Enumeration(
                            serviceName: swagger.serviceName,
                            description: schema.description,
                            typeName: enumTypeName,
                            values: enumValues ?? [],
                            isCodable: true,

                            collectionFormat: nil
                        )
                    )
                    return (.enumeration(typeName: enumTypeName), [model])
                } else {
                    return (type, [])
                }
            case .number(
                let format,
                maximum: _,
                exclusiveMaximum: _,
                minimum: _,
                exclusiveMinimum: _,
                multipleOf: _
            ):
                if let format = format {
                    switch format {
                    case .int32:
                        return (TypeType.int(defaultValue: nil), [])
                    case .long:
                        return (TypeType.int64(defaultValue: nil), [])
                    case .float:
                        return (TypeType.float(defaultValue: nil), [])
                    case .double:
                        return (TypeType.double(defaultValue: nil), [])
                    case .string, .byte, .binary, .boolean, .date, .dateTime, .password, .email, .unsupported:
                        log("[\(swagger.serviceName)] Unsupported schema type: \(format)")
                        return (.void, [])
                    }
                } else {
                    return (.int(defaultValue: nil), [])
                }
            case .integer(
                format: _,
                maximum: _,
                exclusiveMaximum: _,
                minimum: _,
                exclusiveMinimum: _,
                multipleOf: _
            ):
                return (.int(defaultValue: nil), [])
            case .boolean:
                return (.boolean(defaultValue: nil), [])
            case .array(let items, collectionFormat: _, maxItems: _, minItems: _, uniqueItems: _):
                return try typeOfItems(
                    schema: schema,
                    items: Node.node(items),
                    typeNamePrefix: typeNamePrefix,
                    namespace: namespace,
                    swagger: swagger
                )
            case .object(let required, let properties, let allOf):
                return try objectModelFactory.make(
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
