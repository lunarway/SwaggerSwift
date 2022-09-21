import SwaggerSwiftML

/// The types used in the apis. This is the response types, parameter types and so on
enum ModelDefinition {
    case enumeration(Enumeration)
    case object(Model)
    case array(ArrayModel)
    case typeAlias(TypeAliasModel)
}

extension ModelDefinition {
    var typeName: String {
        switch self {
        case .enumeration(let enumeration):
            return enumeration.typeName
        case .object(let model):
            return model.typeName
        case .array(let model):
            return model.typeName
        case .typeAlias(let model):
            return model.typeName
        }
    }

    func toSwift(serviceName: String?, embedded: Bool, accessControl: APIAccessControl, packagesToImport: [String]) -> String {
        switch self {
        case .enumeration(let enumeration):
            return enumeration.toSwift(serviceName: serviceName,
                                       embedded: embedded,
                                       accessControl: accessControl,
                                       packagesToImport: packagesToImport)
        case .object(let model):
            return model.toSwift(serviceName: serviceName,
                                 embedded: embedded,
                                 accessControl: accessControl,
                                 packagesToImport: packagesToImport)
        case .array(let model):
            return model.toSwift(serviceName: serviceName, embedded: embedded, accessControl: accessControl, packagesToImport: packagesToImport)
        case .typeAlias(let model):
            return model.toSwift(serviceName: serviceName, embedded: embedded, accessControl: accessControl, packagesToImport: packagesToImport)
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
