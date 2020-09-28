/// The types used by the service types, such as models, and enums
enum ModelDefinition {
    case enumeration(Enumeration)
    case model(Model)
}

extension ModelDefinition: Swiftable {
    var typeName: String {
        switch self {
        case .enumeration(let enumeration):
            return enumeration.typeName
        case .model(let model):
            return model.typeName
        }
    }

    func toSwift() -> String {
        switch self {
        case .enumeration(let enumeration):
            return enumeration.toSwift()
        case .model(let model):
            return model.toSwift()
        }
    }
}
