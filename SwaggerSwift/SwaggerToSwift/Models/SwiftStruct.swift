struct SwiftStruct {
    let imports: [String]
    let typeName: String
    let properties: [SwiftProperty]
    let methods: [SwiftMethod]
}

//extension SwiftStruct: CustomStringConvertible {
//    var description: String {
//        let seperator = "    "
//        let props = properties.map { $0.description }.joined(separator: "\n")
//        let methodsString = "\n" + seperator + methods.map { $0.description }
//            .joined(separator: "\n\n")
//            .replacingOccurrences(of: "\n", with: "\n\(seperator)")
//
//        let importStatements = imports.map { "import \($0)" }.joined(separator: "\n") + "\n"
//
//        return """
//        \(importStatements)
//        struct \(typeName) {
//        \(props)
//        \(methodsString)
//        }
//        """
//    }
//}
