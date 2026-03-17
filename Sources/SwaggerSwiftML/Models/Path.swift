/// Describes the operations available on a single path
public struct Path: Decodable {
    public let get: Operation?
    public let put: Operation?
    public let post: Operation?
    public let delete: Operation?
    public let options: Operation?
    public let head: Operation?
    public let patch: Operation?
    public let parameters: [Node<Parameter>]?

    enum CodingKeys: String, CodingKey {
        case get
        case post
        case put
        case patch
        case delete
        case head
        case options
        case parameters
    }

    public init(from decoder: Decoder) throws {
        let con = try decoder.container(keyedBy: CodingKeys.self)
        self.get = try con.decodeIfPresent(Operation.self, forKey: .get)
        self.post = try con.decodeIfPresent(Operation.self, forKey: .post)
        self.put = try con.decodeIfPresent(Operation.self, forKey: .put)
        self.patch = try con.decodeIfPresent(Operation.self, forKey: .patch)
        self.delete = try con.decodeIfPresent(Operation.self, forKey: .delete)
        self.head = try con.decodeIfPresent(Operation.self, forKey: .head)
        self.options = try con.decodeIfPresent(Operation.self, forKey: .options)
        if con.contains(.parameters) {
            var params = [Node<Parameter>]()
            var parameterContainer = try con.nestedUnkeyedContainer(forKey: .parameters)
            while parameterContainer.currentIndex < parameterContainer.count ?? 0 {
                if let reference = try? parameterContainer.decode(Reference.self) {
                    params.append(.reference(reference.ref))
                } else if let parameter = try? parameterContainer.decode(Parameter.self) {
                    params.append(.node(parameter))
                } else {
                    fatalError("Unknown object")
                }
            }
            self.parameters = params
        } else {
            self.parameters = nil
        }
    }
}
