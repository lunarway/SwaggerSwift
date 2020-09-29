/// Represents a Swift enum
struct Enumeration {
    let serviceName: String
    let description: String?
    let typeName: String
    let values: [String]
}

extension Enumeration: Swiftable {
    func toSwift() -> String {
        let comment = description != nil && description!.count > 0 ? "\n\(defaultSpacing)// \(description ?? "")" : ""

        return """
extension \(serviceName) {\(comment)
    enum \(self.typeName): String, Codable {
\(defaultSpacing)\(defaultSpacing)\(values.map { "case \($0)" }.joined(separator: "\n\(defaultSpacing)\(defaultSpacing)"))
    }
}
"""
    }
}
