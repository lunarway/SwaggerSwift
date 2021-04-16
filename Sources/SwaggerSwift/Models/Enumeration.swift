/// Represents a Swift enum
struct Enumeration {
    let serviceName: String
    let description: String?
    let typeName: String
    let values: [String]
}

extension Enumeration: Swiftable {
    func toSwift(swaggerFile: SwaggerFile) -> String {
        let comment = description != nil && description!.count > 0 ? "\n\(defaultSpacing)// \(description ?? "")" : ""

        return """
extension \(serviceName) {\(comment)
    public enum \(self.typeName): String, Codable {
\(defaultSpacing)\(defaultSpacing)\(values.sorted(by: { $0 < $1 }).map { "case \($0)" }.joined(separator: "\n\(defaultSpacing)\(defaultSpacing)"))
    }
}
"""
    }
}
