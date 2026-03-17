import Foundation

public enum Node<T: Decodable>: Decodable {
    case reference(String)
    case node(T)

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let ref = try? container.decode(Reference.self) {
            self = .reference(ref.ref)
        } else if let prop = try? container.decode(T.self) {
            self = .node(prop)
        } else {
            throw DecodingError.valueNotFound(
                Node.self,
                .init(codingPath: decoder.codingPath, debugDescription: "Failed to decode node")
            )
        }
    }
}
