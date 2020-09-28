struct SwiftEnum: SwiftType {
    let typeName: String
    let options: [String]
}

extension SwiftEnum: CustomStringConvertible {
    var description: String {
        return """
        enum \(typeName): String, Codable {
        \(options.map { "\(defaultSpacing)case \($0)" }.joined(separator: "\n"))
        }
        """
    }
}
