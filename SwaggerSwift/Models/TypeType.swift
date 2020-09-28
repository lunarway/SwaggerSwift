import SwaggerSwiftML

/// Describes the types that can be returned from a function
indirect enum TypeType {
    case string
    case int
    case double
    case float
    case boolean
    case int64
    case array( typeName: TypeType)
    case object(typeName: String)
    case date
    case void

    func toString() -> String {
        switch self {
        case .string:
            return "String"
        case .int:
            return "Int"
        case .double:
            return "Double"
        case .array(typeName: let typeName):
            return "[\(typeName.toString())]"
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
    }
}

func getType(forSchema schema: SwaggerSwiftML.Schema, typeNamePrefix: String, swagger: Swagger) -> (TypeType, [ModelDefinition]) {
    switch schema.type {
    case .string(format: let format, let enumValues, _, _, _):
        if let enumValues = enumValues {
            let def = ModelDefinition.enumeration(Enumeration(typeName: "\(typeNamePrefix)Options", values: enumValues))
            return (.string, [def])
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
            case .long: fallthrough
            case .float: fallthrough
            case .double: fallthrough
            case .byte: fallthrough
            case .binary: fallthrough
            case .boolean: fallthrough
            case .int32:
                fatalError("Found unsupported field")
            case .unsupported(let unsupported):
                switch unsupported {
                case "ISO8601":
                return (.date, [])
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
        let type = typeOfItems(items: items, typeNamePrefix: typeNamePrefix, swagger: swagger)
        return (.array(typeName: type.0), type.1)
    case .object(let properties, allOf: let allOf):
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
                case .node(let schema):
                    if case let SchemaType.object(properties, allOf) = schema.type {
                        assert(allOf == nil, "Not implemented")
                        let result: [(ModelField, [ModelDefinition])] = properties.map {
                            switch $0.value {
                            case .reference(let reference):
                                let node = swagger.findSchema(node: .reference(reference))
                                if case SchemaType.object = node.type {
                                    let typeName = reference.components(separatedBy: "/").last ?? ""
                                    return (ModelField(description: nil, type: .object(typeName: typeName), name: $0.key, required: true), [])
                                } else {
                                    let type = getType(forSchema: node, typeNamePrefix: typeNamePrefix, swagger: swagger)
                                    return (ModelField(description: nil, type: type.0, name: $0.key, required: true), type.1)
                                }
                            case .node(let schema):
                                let type = getType(forSchema: schema, typeNamePrefix: typeNamePrefix, swagger: swagger)
                                return (ModelField(description: nil, type: type.0, name: $0.key, required: true), type.1)
                            }
                        }

                        return (nil, result.map { $0.0 }, result.flatMap { $0.1 })
                    } else {
                        fatalError("Not implemented")
                    }
                }
            }

            let inherits = result.compactMap { $0.0 }

            let model = Model(serviceName: swagger.serviceName,
                              description: nil,
                              typeName: typeNamePrefix,
                              field: result.flatMap { $0.1 },
                              inheritsFrom: inherits)

            let models = result.flatMap { $0.2 } + [.model(model)]

            return (.object(typeName: typeNamePrefix), models)
        }

        let result: [(ModelField, [ModelDefinition])] = properties.map {
            switch $0.value {
            case .reference(let reference):
                let node = swagger.findSchema(node: .reference(reference))
                if case SchemaType.object = node.type {
                    let typeName = reference.components(separatedBy: "/").last ?? ""
                    return (ModelField(description: nil, type: .object(typeName: typeName), name: $0.key, required: true), [])
                } else {
                    let type = getType(forSchema: node, typeNamePrefix: typeNamePrefix, swagger: swagger)
                    return (ModelField(description: nil, type: type.0, name: $0.key, required: true), type.1)
                }
            case .node(let schema):
                let type = getType(forSchema: schema, typeNamePrefix: typeNamePrefix, swagger: swagger)
                return (ModelField(description: nil, type: type.0, name: $0.key, required: true), type.1)
            }
        }

        let fields = result.map { $0.0 }
        var inlineModels = result.flatMap { $0.1 }

        let model = Model(serviceName: swagger.serviceName, description: nil, typeName: typeNamePrefix, field: fields, inheritsFrom: [])
        inlineModels.append(.model(model))

        return (.object(typeName: typeNamePrefix), inlineModels)
    case .dictionary(valueType: _, keys: _):
        return (.string, [])
    }
}

private func typeOfItems(items: Node<Items>, typeNamePrefix: String, swagger: Swagger) -> (TypeType, [ModelDefinition]) {
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
            return typeOfItems(items: Node.node(items), typeNamePrefix: typeNamePrefix, swagger: swagger)
        }
    }
}
