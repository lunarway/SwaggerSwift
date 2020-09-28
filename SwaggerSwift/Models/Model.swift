/// Represents some kind of network model. This could be a response type or a request type.
struct Model {
    let serviceName: String
    let description: String?
    let typeName: String
    let field: [ModelField]
    let inheritsFrom: [String]
}

extension Model: Swiftable {
    func toSwift() -> String {
        return """
extension \(serviceName) {
    struct \(typeName): \((inheritsFrom + ["Codable"]).joined(separator: ", ")) {
        \(field.sorted(by: { $0.name < $1.name }).map { "let \($0.name): \($0.type.toString())\($0.required ? "" : "?")" }.joined(separator: "\n        "))
    }
}
"""
    }
}
