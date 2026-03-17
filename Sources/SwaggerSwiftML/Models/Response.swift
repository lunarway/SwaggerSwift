// Describes a single response from an API Operation.
public struct Response: Decodable {
    // A short description of the response
    public let description: String?
    /// A definition of the response structure. It can be a primitive, an array or an object. If this field does not exist, it means no content is returned as part of the
    /// response. As an extension to the Schema Object, its root type value may also be "file". This SHOULD be accompanied by a relevant produces mime-type.
    public let schema: Node<Schema>?
    // A list of headers that are sent with the response.
    public let headers: [String: HeaderObject]?

    enum CodingKeys: String, CodingKey {
        case description
        case schema
        case headers
    }

    public init(schema: Schema) {
        self.schema = Node.node(schema)
        self.description = nil
        self.headers = nil
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.description = try container.decodeIfPresent(String.self, forKey: .description)
        self.schema = try container.decodeIfPresent(NodeWrapper<Schema>.self, forKey: .schema)?.value

        if container.contains(.headers) {
            let headerKeysContainer = try container.nestedContainer(
                keyedBy: RawCodingKeys.self,
                forKey: .headers
            )

            var headers = [String: HeaderObject]()
            try headerKeysContainer.allKeys.map {
                ($0.stringValue, try headerKeysContainer.decode(HeaderObject.self, forKey: $0))
            }.forEach { headers[$0] = $1 }

            self.headers = headers
        } else {
            self.headers = nil
        }
    }
}
