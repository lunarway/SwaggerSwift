/// Represents a Swift enum
struct Enumeration {
    let typeName: String
    let values: [String]
}

extension Enumeration: Swiftable {
    func toSwift() -> String {
        return """
enum \(self.typeName) {
    \(values.map { "case \($0)" }.joined(separator: "\n    "))
}
"""
    }
}
