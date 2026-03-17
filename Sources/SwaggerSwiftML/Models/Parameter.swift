/// Describes a single operation parameter.
/// A unique parameter is defined by a combination of a name and location.
public struct Parameter: Decodable {
    /// The name of the parameter. Parameter names are case sensitive.
    public let name: String
    /// The location of the parameter
    public let location: ParameterLocation
    /// A brief description of the parameter
    public let description: String?
    /// Determines whether this parameter is mandatory. If the parameter is in "path", this property is required and its value MUST be true. Otherwise, the property MAY be included and its default value is false.
    public let required: Bool

    enum CodingKeys: String, CodingKey {
        case name
        case location = "in"
        case description
        case required
        case type
        case schema
        case format
        case allowEmptyValue
        case items
        case collectionFormat
        case defaultValue = "default"
        case maximum
        case exclusiveMaximum
        case minimum
        case exclusiveMinimum
        case maxLength
        case minLength
        case pattern
        case maxItems
        case minItems
        case uniqueItems
        case enumeration = "enum"
        case multipleOf
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.name = try container.decode(String.self, forKey: .name)
        let location = try container.decode(String.self, forKey: .location)
        self.description = try container.decodeIfPresent(String.self, forKey: .description)
        let required = try container.decodeIfPresent(Bool.self, forKey: .required)
        self.required = required ?? false

        let typeString = try container.decodeIfPresent(String.self, forKey: .type)  // ParameterType
        let format = try container.decodeIfPresent(DataFormat.self, forKey: .format)

        let maximum = try container.decodeIfPresent(Int.self, forKey: .maximum)
        let exclusiveMaximum = try container.decodeIfPresent(Bool.self, forKey: .exclusiveMaximum)
        let minimum = try container.decodeIfPresent(Int.self, forKey: .minimum)
        let exclusiveMinimum = try container.decodeIfPresent(Bool.self, forKey: .exclusiveMinimum)
        let maxLength = try container.decodeIfPresent(Int.self, forKey: .maxLength)
        let minLength = try container.decodeIfPresent(Int.self, forKey: .minLength)
        let pattern = try container.decodeIfPresent(String.self, forKey: .pattern)
        let maxItems = try container.decodeIfPresent(Int.self, forKey: .maxItems)
        let minItems = try container.decodeIfPresent(Int.self, forKey: .minItems)
        let enumeration = try container.decodeIfPresent([String].self, forKey: .enumeration)
        let multipleOf = try container.decodeIfPresent(Int.self, forKey: .multipleOf)

        let type: ParameterType?
        switch typeString {
        case "array":
            let uniqueItems = try container.decodeIfPresent(Bool.self, forKey: .uniqueItems)
            let collectionFormat =
                (try container.decodeIfPresent(CollectionFormat.self, forKey: .collectionFormat)) ?? .csv

            if let items = try? container.decode(Items.self, forKey: .items) {
                type = .array(
                    .node(items),
                    collectionFormat: collectionFormat,
                    maxItems: maxItems,
                    minItems: minItems,
                    uniqueItems: uniqueItems ?? false
                )
            } else if let reference = try? container.decode(Reference.self, forKey: .items) {
                type = .array(
                    .reference(reference.ref),
                    collectionFormat: collectionFormat,
                    maxItems: maxItems,
                    minItems: minItems,
                    uniqueItems: uniqueItems ?? false
                )
            } else {
                throw InvalidArrayType()
            }

        case "boolean":
            type = .boolean
        case "file":
            type = .file
        case "integer":
            type = .integer(
                format: format,
                maximum: maximum,
                exclusiveMaximum: exclusiveMaximum,
                minimum: minimum,
                exclusiveMinimum: exclusiveMinimum,
                multipleOf: multipleOf
            )
        case "number":
            type = .number(
                format: format,
                maximum: maximum,
                exclusiveMaximum: exclusiveMaximum,
                minimum: minimum,
                exclusiveMinimum: exclusiveMinimum,
                multipleOf: multipleOf
            )
        case "string":
            type = .string(
                format: format,
                enumValues: enumeration,
                maxLength: maxLength,
                minLength: minLength,
                pattern: pattern
            )
        default:
            type = nil
        }

        switch location {
        case "body":
            let schema = try container.decode(NodeWrapper<Schema>.self, forKey: .schema)
            self.location = .body(schema: schema)
        case "query":
            guard let stype = type else { throw SwaggerParseError.missingField }
            let allowEmptyValue =
                (try container.decodeIfPresent(Bool.self, forKey: .allowEmptyValue)) ?? false
            self.location = .query(type: stype, allowEmptyValue: allowEmptyValue)
        case "header":
            guard let stype = type else { throw SwaggerParseError.missingField }
            self.location = .header(type: stype)
        case "path":
            guard let stype = type else { throw SwaggerParseError.missingField }
            self.location = .path(type: stype)
        case "formData":
            guard let stype = type else { throw SwaggerParseError.missingField }
            let allowEmptyValue =
                (try container.decodeIfPresent(Bool.self, forKey: .allowEmptyValue)) ?? false
            self.location = .formData(type: stype, allowEmptyValue: allowEmptyValue)
        default:
            throw SwaggerParseError.invalidField(location)
        }
    }
}

struct InvalidArrayType: Error {}
