/// Represents a single field on a Model
struct ModelField {
    let description: String?
    let type: TypeType
    let name: String
    let required: Bool
}

extension ModelField {
    var toSwift: String {
        let declaration = "public let \(name): \(type.toString())\(required ? "" : "?")"
        if let desc = description {
            return """
// \(desc)
\(declaration)
"""
        } else {
            return declaration
        }
    }
}
