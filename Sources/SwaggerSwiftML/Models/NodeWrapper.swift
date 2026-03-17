public struct NodeWrapper<T: Decodable> {
    public let value: Node<T>
}

public enum NodeWrapperError: Error {
    case invalidType(Error)
}

extension NodeWrapper: Decodable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let ref = try? container.decode(Reference.self) {
            self.value = .reference(ref.ref)
        } else {
            do {
                let result = try container.decode(T.self)
                self.value = .node(result)
            } catch let error {
                throw NodeWrapperError.invalidType(error)
            }
        }
    }
}
