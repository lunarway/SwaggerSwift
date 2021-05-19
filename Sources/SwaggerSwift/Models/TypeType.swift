import Foundation
import SwaggerSwiftML

/// Describes the types that can be returned from a function
indirect enum TypeType {
    case string
    case int
    case double
    case float
    case boolean
    case int64
    case array(typeName: TypeType)
    case object(typeName: String)
    case date
    case void

    func toString(required: Bool) -> String {
        return { obj -> String in
            switch obj {
            case .string:
                return "String"
            case .int:
                return "Int"
            case .double:
                return "Double"
            case .array(typeName: let typeName):
                return "[\(typeName.toString(required: true))]"
            case .object(typeName: let typeName):
                return typeName
            case .void:
                return "Void"
            case .boolean:
                return "Bool"
            case .float:
                return "Float"
            case .int64:
                return "Int64"
            case .date:
                return "Date"
            }
        }(self) + (required ? "" : "?")
    }
}

func getType(forSchema schema: SwaggerSwiftML.Schema, typeNamePrefix: String, swagger: Swagger) -> (TypeType, [ModelDefinition]) {
    switch schema.type {
    case .string(format: let format, let enumValues, _, _, _):
        if let enumValues = enumValues {
            let enumTypename = typeNamePrefix
            let def = ModelDefinition.enumeration(Enumeration(serviceName: swagger.serviceName, description: schema.description, typeName: enumTypename, values: enumValues))
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
                    return (.object(typeName: "UUID"), [])
                default:
                    fatalError("Found unsupported field: \(unsupported)")
                }
            }
        } else {
            return (.string, [])
        }
    case .integer(let format,_,_,_,_,_): fallthrough
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
    case .boolean:
        return (.boolean, [])
    case .array(let items, _, _, _, _):
        let type = typeOfItems(schema: schema, items: items, typeNamePrefix: typeNamePrefix, swagger: swagger)
        return (.array(typeName: type.0), type.1)
    case .object(let properties, allOf: let allOf):
        return parseObject(required: [], properties: properties, allOf: allOf, swagger: swagger, typeNamePrefix: typeNamePrefix, schema: schema)
    case .dictionary(valueType: let valueType, keys: _):
        switch valueType {
        case .any:
            return (.object(typeName: "[String: String]"), [])
        case .reference(_):
            fatalError("not supported")
        case .schema(_):
            fatalError("not supported")
        }
    }
}

private func typeOfItems(schema: Schema, items: Node<Items>, typeNamePrefix: String, swagger: Swagger) -> (TypeType, [ModelDefinition]) {
    switch items {
    case .reference(let ref):
        let schema = swagger.findSchema(node: .reference(ref))
        if case SchemaType.object = schema.type {
            return (.object(typeName: ref.components(separatedBy: "/").last!), [])
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
            return parseObject(required: required, properties: properties, allOf: allOf, swagger: swagger, typeNamePrefix: typeNamePrefix, schema: schema)
        }
    }
}

extension Schema {
    var isInternalOnly: Bool {
        if let value = self.customFields["x-internal"] {
            return value == "true"
        } else {
            return false
        }
    }
}

extension SwaggerSwiftML.Operation {
    var isInternalOnly: Bool {
        if let value = self.customFields["x-internal"] {
            return value == "true"
        } else {
            return false
        }
    }
}

func parseObject(required: [String], properties: [String: Node<Schema>], allOf: [Node<Schema>]?, swagger: Swagger, typeNamePrefix: String, schema: Schema) -> (TypeType, [ModelDefinition]) {
    if let allOf = allOf {
        let result: [(String?, [ModelField], [ModelDefinition])] = allOf.map {
            switch $0 {
            case .reference(let reference):
                let node = swagger.findSchema(node: .reference(reference))
                if case SchemaType.object = node.type {
                    let typeName = reference.components(separatedBy: "/").last ?? ""
                    return (typeName, [], [])
                } else {
                    let result = getType(forSchema: node, typeNamePrefix: typeNamePrefix, swagger: swagger)
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
                            let type = getType(forSchema: schema, typeNamePrefix: typeNamePrefix, swagger: swagger)
                            return (ModelField(description: schema.description, type: type.0, name: $0.key, required: innerSchema.required.contains($0.key)), type.1)
                        }
                    }

                    return (nil, result.map { $0.0 }, result.flatMap { $0.1 })
                } else {
                    fatalError("Not implemented")
                }
            }
        }

//        let inherits = result.compactMap { $0.0 }

        let model = Model(serviceName: swagger.serviceName,
                          description: schema.description,
                          typeName: typeNamePrefix,
                          fields: result.flatMap { $0.1 },
                          inheritsFrom: ["Codable"],//inherits,
                          isInternalOnly: schema.isInternalOnly)

        let models = result.flatMap { $0.2 } + [.model(model)]

        return (.object(typeName: typeNamePrefix), models)
    }

    let result: [(ModelField, [ModelDefinition])] = properties.map {
        switch $0.value {
        case .reference(let reference):
            let node = swagger.findSchema(node: .reference(reference))
            let typeName = reference.components(separatedBy: "/").last ?? ""
            if case SchemaType.object = node.type {
                return (ModelField(description: node.description, type: .object(typeName: typeName), name: $0.key, required: schema.required.contains($0.key)), [])
            } else {
                let type = getType(forSchema: node, typeNamePrefix: typeName, swagger: swagger)
                return (ModelField(description: node.description, type: type.0, name: $0.key, required: schema.required.contains($0.key)), type.1)
            }
        case .node(let innerSchema):
            let typeName = "\(typeNamePrefix)\($0.key.capitalized)Options"
            let type = getType(forSchema: innerSchema, typeNamePrefix: typeName, swagger: swagger)
            let modelField = ModelField(description: innerSchema.description, type: type.0, name: $0.key, required: required.contains($0.key) || schema.required.contains($0.key))
            return (modelField, type.1)
        }
    }

    let fields = result.map { $0.0 }
    var inlineModels = result.flatMap { $0.1 }

    let model = Model(serviceName: swagger.serviceName,
                      description: schema.description, typeName:
                        typeNamePrefix,
                      fields: fields.sorted(by: { $0.name < $1.name }),
                      inheritsFrom: ["Codable"],
                      isInternalOnly: schema.isInternalOnly)

    inlineModels.append(.model(model))

    return (.object(typeName: typeNamePrefix), inlineModels)
}
