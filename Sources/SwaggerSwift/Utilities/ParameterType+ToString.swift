import SwaggerSwiftML

extension ParameterType {
    func toType(typePrefix: String, swagger: Swagger) -> (TypeType, [ModelDefinition]) {
        switch self {
        case .string(format: let format, enumValues: _, maxLength: _, minLength: _, pattern: _):
            switch format {
            case .none:
                return (.string, [])
            case .some(let some):
                return (typeOfDataFormat(some), [])
            }
        case .number(format: let format, maximum: _, exclusiveMaximum: _, minimum: _, exclusiveMinimum: _, multipleOf: _):
            switch format {
            case .none:
                return (.int, [])
            case .some(let some):
                return (typeOfDataFormat(some), [])
            }
        case .integer(format: let format, maximum: _, exclusiveMaximum: _, minimum: _, exclusiveMinimum: _, multipleOf: _):
            switch format {
            case .none:
                return (.int, [])
            case .some(let some):
                return (typeOfDataFormat(some), [])
            }
        case .boolean:
            return (.boolean, [])
        case .array(let items, collectionFormat: _, maxItems: _, minItems: _, uniqueItems: _):
            return typeOfItems(items.type, typePrefix: typePrefix, swagger: swagger)
        case .file:
            return (.object(typeName: "FormData"), [])
        }
    }
}

private func typeOfItems(_ itemsType: ItemsType, typePrefix: String, swagger: Swagger) -> (TypeType, [ModelDefinition]) {
    switch itemsType {
    case .string(format: let format, let enumValues, _, _, _):
        let modelDefinitions: [ModelDefinition]
        if let enumValues = enumValues {
            modelDefinitions = [.enumeration(Enumeration(serviceName: swagger.serviceName, description: nil, typeName: "\(typePrefix)Enum", values: enumValues, isCodable: true))]
        } else {
            modelDefinitions = []
        }

        if let format = format {
            return (typeOfDataFormat(format), modelDefinitions)
        } else {
            return (.string, modelDefinitions)
        }
    case .number(format: let format, _, _, _, _, _):
        if let format = format {
            return (typeOfDataFormat(format), [])
        } else {
            return (.int, [])
        }
    case .integer(format: let format, _, _, _, _, _):
        if let format = format {
            return (typeOfDataFormat(format), [])
        } else {
            return (.int, [])
        }
    case .boolean:
        return (.boolean, [])
    case .array(let itemsType, collectionFormat: _, maxItems: _, minItems: _, uniqueItems: _):
        return typeOfItems(itemsType.type, typePrefix: typePrefix, swagger: swagger)
    case .object(required: _, properties: _, allOf: _):
        fatalError("I dont think this can happen")
    }
}

private func typeOfDataFormat(_ dataFormat: DataFormat) -> TypeType {
    switch dataFormat {
    case .int32:
        return .int
    case .long:
        return .int
    case .float:
        return .int
    case .double:
        return .int
    case .string:
        return .string
    case .byte:
        fatalError("not supported")
    case .binary:
        fatalError("not supported")
    case .boolean:
        return .boolean
    case .date:
        return .object(typeName: "Date")
    case .dateTime:
        return .object(typeName: "Date")
    case .password:
        return .string
    case .email:
        return .string
    case .unsupported(let typeName):
        switch typeName {
        case "int64":
            return .int64
        case "uuid":
            return .object(typeName: "String")
        default:
            fatalError("not supported: \(typeName)")
        }
    }
}
