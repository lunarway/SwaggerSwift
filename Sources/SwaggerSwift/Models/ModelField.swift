/// Represents a single field on a Model
struct ModelField {
    let description: String?
    let type: TypeType
    let required: Bool
    let argumentLabel: String
    let safePropertyName: SafePropertyName
    let safeParameterName: SafeParameterName
    var needsArgumentLabel: Bool {
        return argumentLabel != safeParameterName.value
    }

    init(description: String?, type: TypeType, name: String, required: Bool) {
        self.description = description
        self.type = type
        self.argumentLabel = name
        self.safePropertyName = SafePropertyName(name)
        self.safeParameterName = SafeParameterName(name)
        self.required = required
    }
}

extension ModelField {
    var toSwift: String {
        let declaration = "public let \(safePropertyName): \(type.toString(required: required))"
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
