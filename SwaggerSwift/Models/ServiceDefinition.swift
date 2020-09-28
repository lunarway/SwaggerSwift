struct ServiceField {
    let name: String
    let typeName: String
}

struct ModelField {
    let description: String?
    let type: TypeType
    let name: String
    let required: Bool
}

struct Model {
    let description: String?
    let typeName: String
    let field: [ModelField]
}

struct Enumeration {
    let typeName: String
    let values: [String]
}

/// The types used by the service types, such as models, and enums
enum ModelDefinition {
    case enumeration(Enumeration)
    case model(Model)
}

struct ServiceDefinition {
    let typeName: String
    let fields: [ServiceField]
    let functions: [NetworkRequestFunction]
    let innerTypes: [ModelDefinition]
}

protocol Printable {
    var typeName: String { get }
    func print() -> String
}

extension Model: Printable {
    func print() -> String {
        return """
struct \(typeName): Codable {
    \(field.map { "let \($0.name): \($0.type.toString())\($0.required ? "" : "?")" }.joined(separator: "\n    "))
}
"""
    }
}

extension Enumeration: Printable {
    func print() -> String {
        return """
enum \(self.typeName) {
    \(values.map { "case \($0)" }.joined(separator: "\n    "))
}
"""
    }
}

extension ModelDefinition: Printable {
    var typeName: String {
        switch self {
        case .enumeration(let enumeration):
            return enumeration.typeName
        case .model(let model):
            return model.typeName
        }
    }

    func print() -> String {
        switch self {
        case .enumeration(let enumeration):
            return enumeration.print()
        case .model(let model):
            return model.print()
        }
    }
}
