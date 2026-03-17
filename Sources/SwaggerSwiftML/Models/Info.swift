// https://github.com/OAI/OpenAPI-Specification/blob/master/versions/2.0.md#infoObject

/// The object provides metadata about the API. The metadata can be used by the clients if needed, and can be presented in the Swagger-UI for convenience.
public struct Info: Decodable {
    /// The title of the application
    public let title: String
    /// A short description of the application. GFM syntax can be used for rich text representation.
    public let description: String?
    /// The Terms of Service for the API.
    public let termsOfService: String?
    /// The contact information for the exposed API.
    public let contact: Contact?
    /// The license information for the exposed API.
    public let license: License?
    /// Provides the version of the application API (not to be confused with the specification version).
    public let version: String
}
