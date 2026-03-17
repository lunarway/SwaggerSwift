// til parsing: , allowEmptyValue: Bool defaulter til false
public enum ParameterLocation {
    case query(type: ParameterType, allowEmptyValue: Bool)
    case header(type: ParameterType)
    case path(type: ParameterType)
    case formData(type: ParameterType, allowEmptyValue: Bool)
    case body(schema: NodeWrapper<Schema>)

    var rawValue: String {
        switch self {
        case .query:
            return "query"
        case .header:
            return "header"
        case .path:
            return "path"
        case .formData:
            return "formData"
        case .body:
            return "body"
        }
    }
}
