import SwaggerSwiftML

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

    func toSwift(serviceName: String?, swaggerFile: SwaggerFile, embedded: Bool) -> String {
        switch self {
        case .enumeration(let enumeration):
            return enumeration.toSwift(serviceName: serviceName,
                                       swaggerFile: swaggerFile,
                                       embedded: embedded)
        case .model(let model):
            return model.toSwift(serviceName: serviceName,
                                 swaggerFile: swaggerFile,
                                 embedded: embedded)
        case .interface(let interface):
            return interface.toSwift(serviceName: serviceName,
                                     swaggerFile: swaggerFile,
                                     embedded: embedded)
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
