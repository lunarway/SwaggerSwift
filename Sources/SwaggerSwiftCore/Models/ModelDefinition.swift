import SwaggerSwiftML

enum ModelCodingConformance {
    case none
    case encodable
    case decodable
    case codable

    var isEncodable: Bool {
        switch self {
        case .none, .decodable:
            return false
        case .encodable, .codable:
            return true
        }
    }

    var isDecodable: Bool {
        switch self {
        case .none, .encodable:
            return false
        case .decodable, .codable:
            return true
        }
    }

    static func from(isEncodable: Bool, isDecodable: Bool) -> ModelCodingConformance {
        switch (isEncodable, isDecodable) {
        case (true, true):
            return .codable
        case (true, false):
            return .encodable
        case (false, true):
            return .decodable
        case (false, false):
            return .none
        }
    }
}

/// The types used in the apis. This is the response types, parameter types and so on
enum ModelDefinition {
    case enumeration(Enumeration)
    case object(Model)
    case array(ArrayModel)
    case typeAlias(TypeAliasModel)
}

extension ModelDefinition {
    var supportsCodableConformanceOptimization: Bool {
        switch self {
        case .object(let model):
            return model.supportsCodableConformanceOptimization
        case .enumeration(let enumeration):
            return enumeration.supportsCodableConformanceOptimization
        case .array, .typeAlias:
            return false
        }
    }

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

    func withConformance(_ conformance: ModelCodingConformance) -> ModelDefinition {
        switch self {
        case .object(let model):
            return .object(
                model.withConformance(
                    isEncodable: conformance.isEncodable,
                    isDecodable: conformance.isDecodable
                )
            )
        case .enumeration(let enumeration):
            return .enumeration(
                enumeration.withConformance(
                    isEncodable: conformance.isEncodable,
                    isDecodable: conformance.isDecodable
                )
            )
        case .array, .typeAlias:
            return self
        }
    }

    func toSwift(
        serviceName: String?,
        embedded: Bool,
        accessControl: APIAccessControl,
        packagesToImport: [String]
    ) -> String {
        switch self {
        case .enumeration(let enumeration):
            return enumeration.toSwift(
                serviceName: serviceName,
                embedded: embedded,
                accessControl: accessControl,
                packagesToImport: packagesToImport
            )
        case .object(let model):
            return model.toSwift(
                serviceName: serviceName,
                embedded: embedded,
                accessControl: accessControl,
                packagesToImport: packagesToImport
            )
        case .array(let model):
            return model.toSwift(
                serviceName: serviceName,
                embedded: embedded,
                accessControl: accessControl,
                packagesToImport: packagesToImport
            )
        case .typeAlias(let model):
            return model.toSwift(
                serviceName: serviceName,
                embedded: embedded,
                accessControl: accessControl,
                packagesToImport: packagesToImport
            )
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
