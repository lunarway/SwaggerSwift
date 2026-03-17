public indirect enum ParameterType {
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
    case file
}
