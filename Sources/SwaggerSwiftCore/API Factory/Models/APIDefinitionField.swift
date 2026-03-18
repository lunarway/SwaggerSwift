struct APIDefinitionField {
    let name: String
    let description: String?
    let typeName: String
    let isRequired: Bool
    let typeIsAutoclosure: Bool
    let typeIsBlock: Bool
    let defaultValue: String?

    var templateContext: [String: Any] {
        var context: [String: Any] = [
            "name": name,
            "typeName": typeName,
            "isRequired": isRequired,
            "typeIsAutoclosure": typeIsAutoclosure,
            "typeIsBlock": typeIsBlock,
        ]
        if let description { context["description"] = description }
        if let defaultValue { context["defaultValue"] = defaultValue }
        return context
    }
}
