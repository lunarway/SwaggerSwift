import SwaggerSwiftML

extension Schema {
    var isInternalOnly: Bool {
        if let value = self.customFields["x-internal"] {
            return value == "true"
        } else {
            return false
        }
    }

    var overridesName: String? {
        if let value = self.customFields["x-override-name"] {
            return value
        } else {
            return nil
        }
    }

    /// Provides the `TypeType` for a schema - this is different from `getType` is in it doesnt parse the schema tree
    /// - Parameter name: the name of the type
    func type(named name: String) -> TypeType {
        switch self.type {
        case .string(_, let enumValues, _, _, _):
            if let enumValues = enumValues, enumValues.count > 0 {
                return TypeType.object(typeName: name)
            } else {
                return TypeType.string
            }
        case .number:
            return .int
        case .integer:
            return .int
        case .boolean(let defaultValue):
            return .boolean(defaultValue: defaultValue)
        case .array:
            return .array(typeName: .object(typeName: name))
        case .object:
            return .object(typeName: name)
        case .freeform:
            return .object(typeName: name)
        case .file:
            return .object(typeName: name)
        case .dictionary:
            return .object(typeName: name)
        }
    }
}
