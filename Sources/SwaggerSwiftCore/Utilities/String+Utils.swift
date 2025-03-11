import Foundation

private let badChars = CharacterSet.alphanumerics.inverted

extension String {
    func capitalizingFirstLetter() -> String {
        return prefix(1).capitalized + dropFirst()
    }

    mutating func capitalizeFirstLetter() {
        self = self.capitalizingFirstLetter()
    }

    var uppercasingFirst: String {
        return prefix(1).uppercased() + dropFirst()
    }

    var lowercasingFirst: String {
        return prefix(1).lowercased() + dropFirst()
    }

    var pascalCased: String {
        return self.lowercased()
            .split(separator: " ")
            .map { $0.lowercased().capitalizingFirstLetter() }
            .joined()
    }

    /// camel cased -> camelCased
    var camelized: String {
        guard !isEmpty else {
            return ""
        }

        if count <= 2 {
            return self
        }

        let parts = self.components(separatedBy: badChars)

        let firstPart = parts.first!
        let first: String
        if firstPart.allSatisfy({ $0.isUppercase }) {
            first = firstPart.lowercased()
        } else {
            first = firstPart.lowercasingFirst
        }
        let rest = parts.dropFirst().map({ String($0).lowercased().uppercasingFirst })

        return ([first] + rest).joined(separator: "")
    }

    mutating func appendLine(_ str: String = "") {
        self += str + "\n"
    }
}
