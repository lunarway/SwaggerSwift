import Foundation

/// Describes a single API operation on a path.
public struct Operation: Decodable {
    /// A list of tags for API documentation control. Tags can be used for logical grouping of operations by resources or any other qualifier.
    //    public let tags: [Tag]?
    /// A short summary of what the operation does. For maximum readability in the swagger-ui, this field SHOULD be less than 120 characters.
    public let summary: String?
    /// A verbose explanation of the operation behavior. GFM syntax can be used for rich text representation.
    public let description: String?
    /// Additional external documentation for this operation.
    public let externalDocs: [ExternalDocumentation]?
    /// Unique string used to identify the operation. The id MUST be unique among all operations described in the API. Tools and libraries MAY use the operationId to uniquely identify an operation, therefore, it is recommended to follow common programming naming conventions.
    public let operationId: String?
    /// A list of MIME types the operation can consume. This overrides the consumes definition at the Swagger Object. An empty value MAY be used to clear the global definition. Value MUST be as described under Mime Types.
    public let consumes: [String]?
    /// A list of MIME types the operation can produce. This overrides the produces definition at the Swagger Object. An empty value MAY be used to clear the global definition. Value MUST be as described under Mime Types.
    public let produces: [String]?
    /// A list of parameters that are applicable for this operation. If a parameter is already defined at the Path Item, the new definition will override it, but can never remove it. The list MUST NOT include duplicated parameters. A unique parameter is defined by a combination of a name and location. The list can use the Reference Object to link to parameters that are defined at the Swagger Object's parameters. There can be one "body" parameter at most.
    public let parameters: [Node<Parameter>]?
    /// The list of possible responses as they are returned from executing this operation.
    public let responses: [Int: Node<Response>?]
    /// The transfer protocol for the operation. Values MUST be from the list: "http", "https", "ws", "wss". The value overrides the Swagger Object schemes definition.
    public let schemes: [Scheme]?
    /// Declares this operation to be deprecated. Usage of the declared operation should be refrained. Default value is false.
    public let deprecated: Bool
    /// A declaration of which security schemes are applied for this operation. The list of values describes alternative security schemes that can be used (that is, there is a logical OR between the security requirements). This definition overrides any declared top-level security. To remove a top-level security declaration, an empty array can be used.
    //    public let security: SecurityRequirement?
    public let customFields: [String: String]

    enum CodingKeys: String, CodingKey {
        case tags
        case summary
        case description
        case externalDocs
        case operationId
        case consumes
        case produces
        case parameters
        case responses
        case schemes
        case deprecated
        case security
    }

    public init(from decoder: Decoder) throws {
        let con = try decoder.container(keyedBy: CodingKeys.self)
        //        self.tags = try con.decodeIfPresent([Tag].self, forKey: .tags)
        self.summary = try con.decodeIfPresent(String.self, forKey: .summary)
        self.description = try con.decodeIfPresent(String.self, forKey: .description)
        self.externalDocs = try con.decodeIfPresent([ExternalDocumentation].self, forKey: .externalDocs)
        self.operationId = try con.decodeIfPresent(String.self, forKey: .operationId)
        self.consumes = try con.decodeIfPresent([String].self, forKey: .consumes)
        self.produces = try con.decodeIfPresent([String].self, forKey: .produces)
        self.responses = try con.decode([Int: Node<Response>?].self, forKey: .responses)

        if con.contains(.parameters) {
            var params = [Node<Parameter>]()
            var parameterContainer = try con.nestedUnkeyedContainer(forKey: .parameters)
            while parameterContainer.currentIndex < parameterContainer.count ?? 0 {
                if let reference = try? parameterContainer.decode(Reference.self) {
                    params.append(.reference(reference.ref))
                } else if let parameter = try? parameterContainer.decode(Parameter.self) {
                    params.append(.node(parameter))
                } else {
                    throw UnknownObject()
                }
            }
            self.parameters = params
        } else {
            self.parameters = nil
        }

        let unknownKeysContainer = try decoder.container(keyedBy: RawCodingKeys.self)
        let keys = unknownKeysContainer.allKeys.filter {
            $0.stringValue.starts(with: "x-", by: { $0 == $1 })
        }

        var customFields = [String: String]()
        keys.map { ($0.stringValue, try? unknownKeysContainer.decode(String.self, forKey: $0)) }
            .forEach { key, value in customFields[key] = value }
        self.customFields = customFields

        self.schemes = try con.decodeIfPresent([Scheme].self, forKey: .schemes)
        self.deprecated = try con.decodeIfPresent(Bool.self, forKey: .deprecated) ?? false
        //        self.security = try con.decodeIfPresent(SecurityRequirement.self, forKey: .security)
    }
}

struct UnknownObject: Error {}
