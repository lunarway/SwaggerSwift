import SwaggerSwiftML

extension ParameterType {
    func toType(typePrefix: String, description: String?, swagger: Swagger) throws -> (TypeType, [ModelDefinition]) {
        switch self {
        case .string(let format, let enumValues, maxLength: _, minLength: _, pattern: _):
            let enumTypeName = typePrefix
            switch format {
            case .none:
                if let enumValues = enumValues {
                    return (.object(typeName: enumTypeName), [.enumeration(.init(serviceName: swagger.serviceName,
                                                                                 description: description,
                                                                                 typeName: enumTypeName,
                                                                                 values: enumValues,
                                                                                 isCodable: true))])
                } else {
                    return (.string(defaultValue: nil), [])
                }
            case .some(let some):
                if let enumValues = enumValues {
                    return (.object(typeName: enumTypeName), [.enumeration(.init(serviceName: swagger.serviceName,
                                                                                 description: description,
                                                                                 typeName: enumTypeName,
                                                                                 values: enumValues,
                                                                                 isCodable: true))])
                } else {
                    return (try typeOfDataFormat(some), [])
                }
            }
        case .number(format: let format, maximum: _, exclusiveMaximum: _, minimum: _, exclusiveMinimum: _, multipleOf: _):
            switch format {
            case .none:
                return (.double(defaultValue: nil), [])
            case .some(let some):
                return (try typeOfDataFormat(some), [])
            }
        case .integer(format: let format, maximum: _, exclusiveMaximum: _, minimum: _, exclusiveMinimum: _, multipleOf: _):
            switch format {
            case .none:
                return (.int(defaultValue: nil), [])
            case .some(let some):
                return (try typeOfDataFormat(some), [])
            }
        case .boolean:
            return (.boolean(defaultValue: nil), [])
        case .array(let items, collectionFormat: _, maxItems: _, minItems: _, uniqueItems: _):
            let (type, embedddedDefinitions) = try typeOfItems(items.type, typePrefix: typePrefix, swagger: swagger)
            return (.array(typeName: type), embedddedDefinitions)
        case .file:
            return (.object(typeName: "FormData"), [])
        }
    }
}

private func typeOfItems(_ itemsType: ItemsType, typePrefix: String, swagger: Swagger) throws -> (TypeType, [ModelDefinition]) {
    switch itemsType {
    case .string(format: let format, let enumValues, _, _, _):
        let modelDefinitions: [ModelDefinition]
        if let enumValues = enumValues {
            modelDefinitions = [.enumeration(Enumeration(serviceName: swagger.serviceName, description: nil, typeName: "\(typePrefix)Enum", values: enumValues, isCodable: true))]
        } else {
            modelDefinitions = []
        }

        if let format = format {
            return (try typeOfDataFormat(format), modelDefinitions)
        } else {
            return (.string(defaultValue: nil), modelDefinitions)
        }
    case .number(format: let format, _, _, _, _, _):
        if let format = format {
            return (try typeOfDataFormat(format), [])
        } else {
            return (.int(defaultValue: nil), [])
        }
    case .integer(format: let format, _, _, _, _, _):
        if let format = format {
            return (try typeOfDataFormat(format), [])
        } else {
            return (.int(defaultValue: nil), [])
        }
    case .boolean:
        return (.boolean(defaultValue: nil), [])
    case .array(let itemsType, collectionFormat: _, maxItems: _, minItems: _, uniqueItems: _):
        return try typeOfItems(itemsType.type, typePrefix: typePrefix, swagger: swagger)
    case .object(required: _, properties: _, allOf: _):
        fatalError("I dont think this can happen")
    }
}

enum TypeOfDataFormatError: Error {
    case unsupportedType(String)
}

private func typeOfDataFormat(_ dataFormat: DataFormat) throws -> TypeType {
    switch dataFormat {
    case .int32:
        return .int(defaultValue: nil)
    case .long:
        return .int(defaultValue: nil)
    case .float:
        return .float(defaultValue: nil)
    case .double:
        return .double(defaultValue: nil)
    case .string:
        return .string(defaultValue: nil)
    case .byte:
        fatalError("Bytes is not supported as a dataformat yet")
    case .binary:
        fatalError("Binary is not supported as a dataformat yet")
    case .boolean:
        return .boolean(defaultValue: nil)
    case .date:
        return .object(typeName: "Date")
    case .dateTime:
        return .object(typeName: "Date")
    case .password:
        return .string(defaultValue: nil)
    case .email:
        return .string(defaultValue: nil)
    case .unsupported(let typeName):
        switch typeName {
        case "int64":
            return .int64(defaultValue: nil)
        case "uuid":
            return .object(typeName: "String")
        case "integer":
            return .int(defaultValue: nil)
        default:
            throw TypeOfDataFormatError.unsupportedType(typeName)
        }
    }
}
