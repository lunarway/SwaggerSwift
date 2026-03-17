/// This is the root document object for the API specification. It combines what previously was the Resource Listing and API Declaration (version 1.2 and earlier) together into one document.
public struct Swagger: Decodable {
    /// Specifies the Swagger Specification version being used. It can be used by the Swagger UI and other clients to interpret the API listing. The value MUST be "2.0".
    public let swagger: String?
    /// The object provides metadata about the API. The metadata can be used by the clients if needed, and can be presented in the Swagger-UI for convenience.
    public let info: Info
    /// The host (name or ip) serving the API. This MUST be the host only and does not include the scheme nor sub-paths. It MAY include a port. If the host is not included, the host serving the documentation is to be used (including the port). The host does not support path templating.
    public let host: String?
    /// The base path on which the API is served, which is relative to the host. If it is not included, the API is served directly under the host. The value MUST start with a leading slash (/). The basePath does not support path templating.
    public let basePath: String?
    /// The transfer protocol of the API. Values MUST be from the list: "http", "https", "ws", "wss". If the schemes is not included, the default scheme to be used is the one used to access the Swagger definition itself.
    public let schemes: [Scheme]?
    /// A list of MIME types the APIs can consume. This is global to all APIs but can be overridden on specific API calls. Value MUST be as described under Mime Types.
    public let consumes: [String]?
    /// A list of MIME types the APIs can produce. This is global to all APIs but can be overridden on specific API calls. Value MUST be as described under Mime Types.
    public let produces: [String]?
    /// Holds the relative paths to the individual endpoints. The path is appended to the basePath in order to construct the full URL. The Paths may be empty, due to ACL constraints.
    /// Maps: ServicePath to Path, e.g. '/ping' -> PingResponse
    public let paths: [String: Path]
    /// An object to hold data types produced and consumed by operations.
    /// Maps model name to schema definition
    public let definitions: [String: Node<Schema>]?
    /// An object to hold parameters that can be used across operations. This property does not define global parameters for all operations.
    public let parameters: [String: Parameter]?
    /// An object to hold responses that can be used across operations. This property does not define global responses for all operations.
    public let responses: [String: Response]?
    /// Security scheme definitions that can be used across the specification.
    public let securityDefinitions: [String: SecurityDefinition]?
    /// A declaration of which security schemes are applied for the API as a whole. The list of values describes alternative security schemes that can be used (that is, there is a logical OR between the security requirements). Individual operations can override this definition.
    public let security: [String: SecurityRequirement]?
    /// A list of tags used by the specification with additional metadata. The order of the tags can be used to reflect on their order by the parsing tools. Not all tags that are used by the Operation Object must be declared. The tags that are not declared may be organized randomly or based on the tools' logic. Each tag name in the list MUST be unique.
    public let tags: [Tag]?
    /// Additional external documentation.
    public let externalDocs: [ExternalDocumentation]?

    internal init() {
        fatalError("Dont call this")
    }

    enum CodingKeys: String, CodingKey {
        case swagger
        case info
        case host
        case basePath
        case schemes
        case consumes
        case produces
        case paths
        case definitions
        case parameters
        case responses
        case securityDefinitions
        case security
        case tags
        case externalDocs
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.swagger = try container.decodeIfPresent(String.self.self, forKey: .swagger)
        self.info = try container.decode(Info.self, forKey: .info)
        self.host = try container.decodeIfPresent(String.self, forKey: .host)
        self.basePath = try container.decodeIfPresent(String.self, forKey: .basePath)
        self.schemes = try container.decodeIfPresent([Scheme].self, forKey: .schemes)
        self.consumes = try container.decodeIfPresent([String].self, forKey: .consumes)
        self.produces = try container.decodeIfPresent([String].self, forKey: .produces)
        self.paths = try container.decode([String: Path].self, forKey: .paths)
        self.definitions = try container.decodeIfPresent([String: Node<Schema>].self, forKey: .definitions)
        self.parameters = try container.decodeIfPresent([String: Parameter].self, forKey: .parameters)
        self.responses = try container.decodeIfPresent([String: Response].self, forKey: .responses)
        self.securityDefinitions = try container.decodeIfPresent(
            [String: SecurityDefinition].self,
            forKey: .securityDefinitions
        )
        self.security = try container.decodeIfPresent(
            [String: SecurityRequirement].self,
            forKey: .security
        )
        self.tags = try container.decodeIfPresent([Tag].self, forKey: .tags)
        self.externalDocs = try container.decodeIfPresent(
            [ExternalDocumentation].self,
            forKey: .externalDocs
        )
    }
}
