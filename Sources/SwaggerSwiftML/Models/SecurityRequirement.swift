public enum ApiKeyLocation: String, Codable {
    case query
    case header
}

public enum SecurityType {
    case basic
    case apiKey(name: String, location: ApiKeyLocation)
    case oauth2(flow: String, authorizationUrl: String, tokenUrl: String, scopes: [String: String])
}

/// Allows the definition of a security scheme that can be used by the operations. Supported schemes are basic authentication, an API key (either as a header or
/// as a query parameter) and OAuth2's common flows (implicit, password, application and access code).
///  - note: https://github.com/OAI/OpenAPI-Specification/blob/master/versions/2.0.md#securityDefinitionsObject
public struct SecurityRequirement: Decodable {
    let type: SecurityType
    let description: String?

    enum CodingKeys: String, CodingKey {
        case type
        case description
        case name
        case location = "in"
        case flow
        case authorizationUrl
        case tokenUrl
        case scopes
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let typeString = try container.decode(String.self, forKey: .type)
        self.description = try container.decodeIfPresent(String.self, forKey: .description)

        switch typeString {
        case "basic":
            self.type = .basic
        case "apiKey":
            let name = try container.decode(String.self, forKey: .name)
            let location = try container.decode(ApiKeyLocation.self, forKey: .location)
            self.type = .apiKey(name: name, location: location)
        case "oauth2":
            let flow = try container.decode(String.self, forKey: .flow)
            let authorizationUrl = try container.decode(String.self, forKey: .authorizationUrl)
            let tokenUrl = try container.decode(String.self, forKey: .tokenUrl)
            let scopes = try container.decode([String: String].self, forKey: .scopes)
            self.type = .oauth2(
                flow: flow,
                authorizationUrl: authorizationUrl,
                tokenUrl: tokenUrl,
                scopes: scopes
            )
        default:
            fatalError("Unknown security type: \(typeString)")
        }
    }
}
