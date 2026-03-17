import Foundation

// https://github.com/OAI/OpenAPI-Specification/blob/master/versions/2.0.md#contactObject

/// Contact information for the exposed API.
public struct Contact: Decodable {
    /// The identifying name of the contact person/organization.
    public let name: String?
    /// The URL pointing to the contact information. MUST be in the format of a URL.
    public let url: URL?
    /// The email address of the contact person/organization. MUST be in the format of an email address.
    public let email: String?
}
