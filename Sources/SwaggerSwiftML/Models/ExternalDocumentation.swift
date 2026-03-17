import Foundation

/// Allows referencing an external resource for extended documentation.
public struct ExternalDocumentation: Codable {
    /// A short description of the target documentation. GFM syntax can be used for rich text representation.
    let description: String?
    /// The URL for the target documentation. Value MUST be in the format of a URL.
    let url: URL
}
