public struct SecurityDefinition: Decodable {
    public let type: String
    public let description: String?
    public let name: String
    public let `in`: String
}
