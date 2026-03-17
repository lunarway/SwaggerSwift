/// Primitive data types in the Swagger Specification are based on the types supported by the JSON-Schema Draft 4. Models are described using the Schema Object which is a subset of JSON Schema Draft 4.
/// An additional primitive data type "file" is used by the Parameter Object and the Response Object to set the parameter type or the response as being a file.
/// Primitives have an optional modifier property format. Swagger uses several known formats to more finely define the data type being used. However, the format property is an open string-valued property, and can have any value to support documentation needs. Formats such as "email", "uuid", etc., can be used even though they are not defined by this specification. Types that are not accompanied by a format property follow their definition from the JSON Schema (except for file type which is defined above).
public enum DataFormat: Decodable {
    // type: integer - format: int32 - comment: signed 32 bits
    case int32

    case long
    case float
    case double
    case string
    // base64 encoded characters
    case byte
    // any sequence of octets
    case binary
    case boolean
    // full-date notation as defined by RFC 3339, section 5.6, for example, 2017-07-21
    case date
    // the date-time notation as defined by RFC 3339, section 5.6, for example, 2017-07-21T17:32:28Z
    case dateTime
    // Used to hint UIs the input needs to be obscured.
    case password
    case email

    case unsupported(String)

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let formatString = try container.decode(String.self)
        switch formatString {
        case "int32":
            self = .int32
        case "long":
            self = .long
        case "float":
            self = .float
        case "double":
            self = .double
        case "string":
            self = .string
        case "byte":
            self = .byte
        case "binary":
            self = .binary
        case "boolean":
            self = .boolean
        case "date":
            self = .date
        case "date-time":
            self = .dateTime
        case "password":
            self = .password
        case "email":
            self = .email
        default:
            self = .unsupported(formatString)
        }
    }
}

extension DataFormat: Equatable {}
