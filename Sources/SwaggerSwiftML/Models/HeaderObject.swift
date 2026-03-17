public struct HeaderObject: Decodable {
    public enum HeaderType {
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
            Node<Items>,
            collectionFormat: CollectionFormat,
            maxItems: Int?,
            minItems: Int?,
            uniqueItems: Bool
        )
    }

    enum CodingKeys: String, CodingKey {
        case format
        case description
        case multipleOf
        case maximum
        case exclusiveMaximum
        case minimum
        case excluesiveMinimum
        case maxLength
        case minLength
        case pattern
        case maxItems
        case minItems
        case uniqueItems
        case maxProperties
        case minProperties
        case enumeration = "enum"
        case type
        case items
        case collectionFormat
    }

    public let description: String?
    public let uniqueItems: Bool
    public let maxProperties: Int?
    public let minProperties: Int?
    public let type: HeaderType
    public let customFields: [String: String]

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let format = try container.decodeIfPresent(DataFormat.self, forKey: .format)
        self.description = try container.decodeIfPresent(String.self, forKey: .description)
        let multipleOf = try container.decodeIfPresent(Int.self, forKey: .multipleOf)
        let maximum = try container.decodeIfPresent(Int.self, forKey: .maximum)
        let exclusiveMaximum = try container.decodeIfPresent(Bool.self, forKey: .exclusiveMaximum)
        let minimum = try container.decodeIfPresent(Int.self, forKey: .minimum)
        let excluesiveMinimum = try container.decodeIfPresent(Bool.self, forKey: .excluesiveMinimum)
        let maxLength = try container.decodeIfPresent(Int.self, forKey: .maxLength)
        let minLength = try container.decodeIfPresent(Int.self, forKey: .minLength)
        let pattern = try container.decodeIfPresent(String.self, forKey: .pattern)
        let maxItems = try container.decodeIfPresent(Int.self, forKey: .maxItems)
        let minItems = try container.decodeIfPresent(Int.self, forKey: .minItems)
        self.uniqueItems = (try container.decodeIfPresent(Bool.self, forKey: .uniqueItems)) ?? false
        self.maxProperties = try container.decodeIfPresent(Int.self, forKey: .maxProperties)
        self.minProperties = try container.decodeIfPresent(Int.self, forKey: .minProperties)
        let enumeration = try container.decodeIfPresent([String].self, forKey: .enumeration)

        let unknownKeysContainer = try decoder.container(keyedBy: RawCodingKeys.self)
        let keys = unknownKeysContainer.allKeys.filter {
            $0.stringValue.starts(with: "x-", by: { $0 == $1 })
        }

        var customFields = [String: String]()
        keys.map { ($0.stringValue, try? unknownKeysContainer.decode(String.self, forKey: $0)) }
            .forEach { key, value in customFields[key] = value }
        self.customFields = customFields

        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "string":
            self.type = .string(
                format: format,
                enumValues: enumeration,
                maxLength: maxLength,
                minLength: minLength,
                pattern: pattern
            )
        case "number":
            self.type = .number(
                format: format,
                maximum: maximum,
                exclusiveMaximum: exclusiveMaximum,
                minimum: minimum,
                exclusiveMinimum: excluesiveMinimum,
                multipleOf: multipleOf
            )
        case "integer":
            self.type = .integer(
                format: format,
                maximum: maximum,
                exclusiveMaximum: exclusiveMaximum,
                minimum: minimum,
                exclusiveMinimum: excluesiveMinimum,
                multipleOf: multipleOf
            )
        case "boolean":
            self.type = .boolean
        case "array":
            let uniqueItems = (try container.decodeIfPresent(Bool.self, forKey: .uniqueItems) ?? false)
            let collectionFormat =
                (try container.decodeIfPresent(CollectionFormat.self, forKey: .collectionFormat)) ?? .csv

            let node: Node<Items>
            if let itemsObject = try? container.decode(Items.self, forKey: .items) {
                node = .node(itemsObject)
            } else if let ref = try? container.decode(Reference.self, forKey: .items) {
                node = .reference(ref.ref)
            } else {
                throw SwaggerError.corruptFile
            }

            self.type = .array(
                node,
                collectionFormat: collectionFormat,
                maxItems: maxItems,
                minItems: minItems,
                uniqueItems: uniqueItems
            )
        default:
            throw SchemaParseError.invalidType("Unsupported type: \(type) found on a schema")
        }
    }
}
