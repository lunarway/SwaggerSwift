struct QueryElement {
    enum ValueType {
        case date
        case `enum`
        case `default`
    }
    let fieldName: String
    let fieldValue: String
    let isOptional: Bool
    let valueType: ValueType
}
