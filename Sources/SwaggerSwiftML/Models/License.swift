import Foundation

// https://github.com/OAI/OpenAPI-Specification/blob/master/versions/2.0.md#licenseObject

/// License information for the exposed API.
public struct License: Decodable {
    /// The license name used for the API.
    public let name: String
    /// A URL to the license used for the API. MUST be in the format of a URL.
    public let url: URL?
}
