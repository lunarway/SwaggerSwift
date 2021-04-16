/// The types used by the service types, such as models, and enums
enum ModelDefinition {
    case enumeration(Enumeration)
    case model(Model)
    case interface(Interface)
}

extension ModelDefinition: Swiftable {
    var typeName: String {
        switch self {
        case .enumeration(let enumeration):
            return enumeration.typeName
        case .model(let model):
            return model.typeName
        case .interface(let model):
            return model.typeName
        }
    }

    func toSwift(swaggerFile: SwaggerFile) -> String {
        switch self {
        case .enumeration(let enumeration):
            return enumeration.toSwift(swaggerFile: swaggerFile)
        case .model(let model):
            return model.toSwift(swaggerFile: swaggerFile)
        case .interface(let interface):
            return interface.toSwift(swaggerFile: swaggerFile)
        }
    }

    func resolveInherits(_ def: [Model]) -> ModelDefinition {
        switch self {
        case .model(let model):
            return .model(model.resolveInherits(def))
        default:
            return self
        }
    }
}
