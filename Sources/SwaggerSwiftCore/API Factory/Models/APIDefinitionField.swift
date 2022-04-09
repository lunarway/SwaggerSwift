struct APIDefinitionField {
    let name: String
    let description: String?
    let typeName: String
    let isRequired: Bool
    let typeIsAutoclosure: Bool
    let typeIsBlock: Bool
    let defaultValue: String?

    var documentationString: String {
        return "///   - \(name): \(description ?? "")"
    }

    var initProperty: String {
        return "\(name): \(typeIsAutoclosure ? "@autoclosure " : "")\(typeIsBlock ? "@escaping " : "")\(typeName)\(isRequired ? "" : "?")\(defaultValue != nil ? " = \(defaultValue!)" : "")"
    }

    var initAssignment: String {
        return "self.\(name) = \(name)"
    }
}
