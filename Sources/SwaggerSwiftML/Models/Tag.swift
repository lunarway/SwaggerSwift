/// Allows adding meta data to a single tag that is used by the Operation Object. It is not mandatory to have a Tag Object per tag used there.
///  - note: https://github.com/OAI/OpenAPI-Specification/blob/master/versions/2.0.md#tagObject
public struct Tag: Codable {
    /// The name of the tag.
    let name: String
    /// A short description for the tag. GFM syntax can be used for rich text representation.
    let description: String?
    /// Additional external documentation for this tag.
    let externalDocs: [ExternalDocumentation]?
}
