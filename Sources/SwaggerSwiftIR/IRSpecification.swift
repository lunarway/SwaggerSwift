/// The root IR type representing a parsed API specification,
/// regardless of whether it originated from Swagger 2.0 or OpenAPI 3.
public struct IRSpecification {
    /// The derived service name (e.g. "MyApi").
    public let serviceName: String
    /// Maps path strings (e.g. "/users/{id}") to their path definitions.
    public let paths: [String: IRPath]
    /// Global MIME types the API can consume.
    public let consumes: [String]?
    /// Top-level schema definitions, keyed by definition name.
    public let schemaDefinitions: [String: IRNode<IRSchema>]
    /// Top-level response definitions, keyed by response name.
    public let responseDefinitions: [String: IRResponse]
    /// Top-level parameter definitions, keyed by parameter name.
    public let parameterDefinitions: [String: IRParameter]

    public init(
        serviceName: String,
        paths: [String: IRPath],
        consumes: [String]?,
        schemaDefinitions: [String: IRNode<IRSchema>],
        responseDefinitions: [String: IRResponse],
        parameterDefinitions: [String: IRParameter]
    ) {
        self.serviceName = serviceName
        self.paths = paths
        self.consumes = consumes
        self.schemaDefinitions = schemaDefinitions
        self.responseDefinitions = responseDefinitions
        self.parameterDefinitions = parameterDefinitions
    }
}

// MARK: - Reference Resolution

public struct IRNotFound: Error {
    public let reference: String

    public init(reference: String) {
        self.reference = reference
    }
}

extension IRSpecification {
    /// Resolves a `$ref` string to a concrete `IRSchema`.
    ///
    /// Normalizes bare names to `#/definitions/<name>`, searches schema definitions
    /// first, then response definitions (extracting the response's schema).
    /// Follows reference chains recursively.
    public func resolveSchema(reference: String) throws -> IRSchema {
        var reference = reference
        if !reference.hasPrefix("#/") {
            reference = "#/definitions/\(reference)"
        }

        for (key, value) in schemaDefinitions {
            let searchName = "#/definitions/\(key)"
            if reference == searchName {
                switch value {
                case .reference(let ref):
                    return try resolveSchema(reference: ref)
                case .node(let schema):
                    return schema
                }
            }
        }

        for (key, value) in responseDefinitions {
            let searchName = "#/responses/\(key)"
            if reference == searchName, let schemaNode = value.schema {
                switch schemaNode {
                case .reference(let ref):
                    return try resolveSchema(reference: ref)
                case .node(let schema):
                    return schema
                }
            }
        }

        throw IRNotFound(reference: reference)
    }

    /// Resolves an `IRNode<IRParameter>` — if it's a reference, looks it up
    /// in `parameterDefinitions`; if it's an inline node, returns it directly.
    public func resolveParameter(node: IRNode<IRParameter>) throws -> IRParameter {
        switch node {
        case .reference(let reference):
            for (key, value) in parameterDefinitions {
                let searchName = "#/parameters/\(key)"
                if reference == searchName {
                    return value
                }
            }
            throw IRNotFound(reference: reference)
        case .node(let parameter):
            return parameter
        }
    }
}
