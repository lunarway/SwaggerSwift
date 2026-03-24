/// A spec-agnostic reference-or-inline wrapper.
/// Unlike `Node<T>` in SwaggerSwiftML, this has no `Decodable` conformance — it's a pure value type.
public enum IRNode<T> {
    case reference(String)
    case node(T)
}
