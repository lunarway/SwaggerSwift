/// Represents some kind of network model. This could be a response type or a request type.
struct Model {
    let description: String?
    let typeName: String
    let field: [ModelField]
}

extension Model: Swiftable {
    func toSwift() -> String {
        return """
struct \(typeName): Codable {
    \(field.map { "let \($0.name): \($0.type.toString())\($0.required ? "" : "?")" }.joined(separator: "\n    "))
}
"""
    }
}
