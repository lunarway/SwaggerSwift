/// Placeholder for a spec-agnostic response definition.
/// Will be filled in by VOID-2513.
public struct IRResponse {
    /// The schema associated with this response, if any.
    public let schema: IRNode<IRSchema>?

    public init(schema: IRNode<IRSchema>? = nil) {
        self.schema = schema
    }
}
