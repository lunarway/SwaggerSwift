public struct Reference: Decodable {
    public let ref: String

    enum CodingKeys: String, CodingKey {
        case ref = "$ref"
    }
}
