struct APIDefinitionField {
    let name: String
    let description: String?
    let typeName: String
    let isRequired: Bool
    let typeIsAutoclosure: Bool
    let typeIsBlock: Bool
    let defaultValue: String?

    var documentationString: String {
        "///   - \(name): \(description ?? "")"
    }

    var initProperty: String {
        "\(name): \(typeIsAutoclosure ? "@autoclosure " : "")\(typeIsBlock ? "@escaping @Sendable" : "")\(typeName)\(isRequired ? "" : "?")\(defaultValue != nil ? " = \(defaultValue!)" : "")"
    }

    var initAssignment: String {
        "self.\(name) = \(name)"
    }
}
