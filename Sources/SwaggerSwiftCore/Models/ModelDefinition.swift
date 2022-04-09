import SwaggerSwiftML

/// The types used in the apis. This is the response types, parameter types and so on
enum ModelDefinition {
    case enumeration(Enumeration)
    case object(Model)
}

extension ModelDefinition: Swiftable {
    var typeName: String {
        switch self {
        case .enumeration(let enumeration):
            return enumeration.typeName
        case .object(let model):
            return model.typeName
        }
    }

    func toSwift(serviceName: String?, swaggerFile: SwaggerFile, embedded: Bool, packagesToImport: [String]) -> String {
        switch self {
        case .enumeration(let enumeration):
            return enumeration.toSwift(serviceName: serviceName,
                                       swaggerFile: swaggerFile,
                                       embedded: embedded,
                                       packagesToImport: packagesToImport)
        case .object(let model):
            return model.toSwift(serviceName: serviceName,
                                 swaggerFile: swaggerFile,
                                 embedded: embedded,
                                 packagesToImport: packagesToImport)
        }
    }

    func resolveInheritanceTree(with models: [Model]) -> ModelDefinition {
        switch self {
        case .object(let model):
            return .object(model.resolveInheritanceTree(withModels: models))
        default:
            return self
        }
    }
}
