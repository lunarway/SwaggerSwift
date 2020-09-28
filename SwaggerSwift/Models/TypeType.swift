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
            case .int32: fallthrough
            case .unsupported(_):
                fatalError("These cannot happen")
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
                default:
                    fatalError("Unsupported field type received: \(unsupported)")
                }
            }
        }

        return (.int, [])
    case .boolean:
        return (.boolean, [])
    case .array(let items, collectionFormat: _, maxItems: _, minItems: let _, uniqueItems: _):
        let type = typeOfItems(items: items, typeNamePrefix: typeNamePrefix, swagger: swagger)
        return (.array(typeName: type.0), type.1)
    case .object(let properties, allOf: _):
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

        let typeName = "\(typeNamePrefix)"
        let model = Model(description: nil, typeName: typeName, field: fields)
        inlineModels.append(.model(model))

        return (.object(typeName: typeName), inlineModels)
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
        case .string(format: let format, enumValues: let enumValues, maxLength: let maxLength, minLength: let minLength, pattern: let pattern):
            return (.string, [])
        case .number(format: let format, maximum: let maximum, exclusiveMaximum: let exclusiveMaximum, minimum: let minimum, exclusiveMinimum: let exclusiveMinimum, multipleOf: let multipleOf):
            return (.int, [])
        case .integer(format: let format, maximum: let maximum, exclusiveMaximum: let exclusiveMaximum, minimum: let minimum, exclusiveMinimum: let exclusiveMinimum, multipleOf: let multipleOf):
            return (.int, [])
        case .boolean:
            return (.boolean, [])
        case .array(let items, collectionFormat: let collectionFormat, maxItems: let maxItems, minItems: let minItems, uniqueItems: let uniqueItems):
            return typeOfItems(items: Node.node(items), typeNamePrefix: typeNamePrefix, swagger: swagger)
        }
    }
}
