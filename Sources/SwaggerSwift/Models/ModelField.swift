import Foundation

/// Represents a single field on a Model
struct ModelField {
    let description: String?
    let type: TypeType
    let required: Bool
    let argumentLabel: String
    let safePropertyName: SafePropertyName
    let safeParameterName: SafeParameterName
    let defaultValue: String?
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
        switch type {
        case .boolean(let defaultValue):
            if let defaultValue = defaultValue {
                if defaultValue {
                    self.defaultValue = "true"
                } else {
                    self.defaultValue = "false"
                }
            } else {
                self.defaultValue = nil
            }
        default:
            self.defaultValue = nil
        }
    }
}

extension ModelField {
    var toSwift: String {
        let declaration = "public let \(safePropertyName): \(type.toString(required: required || defaultValue != nil))"
        if let desc = description {
            return """
\(desc.components(separatedBy: "\n").filter { $0.isEmpty == false }.map { "// \($0)" }.joined(separator: "\n").trimmingCharacters(in: CharacterSet.whitespacesAndNewlines))
\(declaration)
"""
        } else {
            return declaration
        }
    }
}
