public indirect enum ItemsType {
    case string(
        format: DataFormat?,
        enumValues: [String]?,
        maxLength: Int?,
        minLength: Int?,
        pattern: String?
    )
    case number(
        format: DataFormat?,
        maximum: Int?,
        exclusiveMaximum: Bool?,
        minimum: Int?,
        exclusiveMinimum: Bool?,
        multipleOf: Int?
    )
    case integer(
        format: DataFormat?,
        maximum: Int?,
        exclusiveMaximum: Bool?,
        minimum: Int?,
        exclusiveMinimum: Bool?,
        multipleOf: Int?
    )
    case boolean
    case array(
        Items,
        collectionFormat: CollectionFormat,
        maxItems: Int?,
        minItems: Int?,
        uniqueItems: Bool
    )
    case object(required: [String], properties: [String: Node<Schema>], allOf: [Node<Schema>]?)
}

public struct Items: Decodable {
    public let type: ItemsType
    public let customFields: [String: String]

    enum CodingKeys: String, CodingKey {
        case type
        case format
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
        case additionalProperties
        case allOf
        case properties
        case required
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

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
        let uniqueItems = try container.decodeIfPresent(Bool.self, forKey: .uniqueItems)
        let enumeration = try container.decodeIfPresent([String].self, forKey: .enumeration)
        let multipleOf = try container.decodeIfPresent(Int.self, forKey: .multipleOf)
        let required = try container.decodeIfPresent([String].self, forKey: .required)

        let unknownKeysContainer = try decoder.container(keyedBy: RawCodingKeys.self)
        let keys = unknownKeysContainer.allKeys.filter {
            $0.stringValue.starts(with: "x-", by: { $0 == $1 })
        }

        var customFields = [String: String]()
        keys.map { ($0.stringValue, try? unknownKeysContainer.decode(String.self, forKey: $0)) }
            .forEach { key, value in customFields[key] = value }
        self.customFields = customFields

        var typeString = try container.decodeIfPresent(String.self, forKey: .type)
        if typeString == nil {
            if container.contains(.properties) || container.contains(.allOf) {
                typeString = "object"
            } else {
                throw SwaggerError.failedToParse(description: "", codingPath: container.codingPath)
            }
        }

        guard let type = typeString else { fatalError("Failed to find type on schema") }

        switch type {
        case "array":
            let collectionFormat =
                (try container.decodeIfPresent(CollectionFormat.self, forKey: .collectionFormat)) ?? .csv
            let items = try container.decode(Items.self, forKey: .items)
            self.type = .array(
                items,
                collectionFormat: collectionFormat,
                maxItems: maxItems,
                minItems: minItems,
                uniqueItems: uniqueItems ?? false
            )
        case "boolean":
            self.type = .boolean
        case "integer":
            self.type = .integer(
                format: format,
                maximum: maximum,
                exclusiveMaximum: exclusiveMaximum,
                minimum: minimum,
                exclusiveMinimum: exclusiveMinimum,
                multipleOf: multipleOf
            )
        case "number":
            self.type = .number(
                format: format,
                maximum: maximum,
                exclusiveMaximum: exclusiveMaximum,
                minimum: minimum,
                exclusiveMinimum: exclusiveMinimum,
                multipleOf: multipleOf
            )
        case "string":
            self.type = .string(
                format: format,
                enumValues: enumeration,
                maxLength: maxLength,
                minLength: minLength,
                pattern: pattern
            )
        case "object":
            let isDictionary = container.contains(.additionalProperties)
            if isDictionary {
                fatalError("I dont support dictionaries in arrays... yet")
            }

            let allOf = try container.decodeIfPresent([NodeWrapper<Schema>].self, forKey: .allOf)
                .map { $0.map { $0.value } }

            let properties = try container.decodeIfPresent(
                [String: NodeWrapper<Schema>].self,
                forKey: .properties
            )?.compactMapValues { $0.value }

            self.type = .object(
                required: required ?? [],
                properties: properties ?? [:],
                allOf: allOf
            )
        default:
            throw SwaggerParseError.invalidField(typeString ?? "No field found on Items")
        }
    }
}
