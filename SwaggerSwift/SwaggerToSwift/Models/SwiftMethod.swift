import Foundation

fileprivate let badChars = CharacterSet.alphanumerics.inverted

extension String {
    var uppercasingFirst: String {
        return prefix(1).uppercased() + dropFirst()
    }
    
    var lowercasingFirst: String {
        return prefix(1).lowercased() + dropFirst()
    }

    var camelized: String {
        guard !isEmpty else {
            return ""
        }

        let parts = self.components(separatedBy: badChars)

        let first = String(describing: parts.first!).lowercasingFirst
        let rest = parts.dropFirst().map({String($0).uppercasingFirst})

        return ([first] + rest).joined(separator: "")
    }
}

struct SwiftMethodParameter {
    let name: String
    let type: String
}

struct SwiftMethod {
    let discardableResult: Bool
    let documentation: String?
    let functionName: String
    let parameters: [SwiftMethodParameter]
    let returnValue: String
    let body: String
}

extension SwiftMethod: CustomStringConvertible {
    var description: String {
        let parameterList = parameters.map { "\($0.name.camelized): \($0.type)" }.joined(separator: ", ")
        let doc = (documentation != nil ? "// \(documentation!)\n" : "") + ""

        return doc + """
        \(discardableResult ? "@discardableResult" : "")
        func \(functionName)(\(parameterList)) -> \(returnValue) {
        \(body)
        }
        """
    }
}
