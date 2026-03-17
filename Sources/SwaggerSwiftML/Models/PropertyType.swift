public enum PropertyType {
    case string
    case number
    case integer
    case boolean
    case array
    case file
    case object
    case enumeration

    var rawValue: String {
        switch self {
        case .string:
            return "string"
        case .number:
            return "number"
        case .integer:
            return "integer"
        case .boolean:
            return "boolean"
        case .array:
            return "array"
        case .file:
            return "file"
        case .object:
            return "object"
        case .enumeration:
            return "enum"
        }
    }
}
