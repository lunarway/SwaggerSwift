/// Schema types
public indirect enum SchemaType {
    case string(
        format: DataFormat?,
        enumValues: [String]?,
        maxLength: Int?,
        minLength: Int?,
        pattern: String?,
        defaultValue: String?
    )
    case number(
        format: DataFormat?,
        maximum: Int?,
        exclusiveMaximum: Bool?,
        minimum: Int?,
        exclusiveMinimum: Bool?,
        multipleOf: Int?,
        defaultValue: Double?
    )
    case integer(
        format: DataFormat?,
        maximum: Int?,
        exclusiveMaximum: Bool?,
        minimum: Int?,
        exclusiveMinimum: Bool?,
        multipleOf: Int?,
        defaultValue: Int?
    )
    case boolean(defaultValue: Bool?)
    case array(
        Node<Items>,
        collectionFormat: CollectionFormat,
        maxItems: Int?,
        minItems: Int?,
        uniqueItems: Bool
    )
    // Complex object type
    // - Parameter properties: the list of properties (or fields) that are present on types. This can be nil if the object is free-form (see https://swagger.io/docs/specification/data-models/data-types/#object)
    case object(properties: [String: Node<Schema>], allOf: [Node<Schema>]?)
    case freeform
    case file

    // The schema represents a dictionary type, i.e. a [String: <something>]
    // - valueType: the value type of the dictionary, i.e. the `something`
    // - keys: if there are any keys that are required to be filled out in the object they are defined here
    case dictionary(valueType: DictionaryValueType, keys: [KeyType])
}
