import Foundation

fileprivate let badChars = CharacterSet.alphanumerics.inverted

extension String {
    func capitalizingFirstLetter() -> String {
        return prefix(1).capitalized + dropFirst()
    }

    mutating func capitalizeFirstLetter() {
        self = self.capitalizingFirstLetter()
    }

    var uppercasingFirst: String {
        return prefix(1).uppercased() + dropFirst().lowercased()
    }

    var pascalCased: String {
        return self.lowercased()
            .split(separator: " ")
            .map { $0.lowercased().capitalizingFirstLetter() }
            .joined()
    }

    var camelized: String {
        guard !isEmpty else {
            return ""
        }

        if count <= 2 {
            return self
        }

        let parts = self.components(separatedBy: badChars)

        let first = String(describing: parts.first!).lowercased()
        let rest = parts.dropFirst().map({String($0).uppercasingFirst})

        return ([first] + rest).joined(separator: "")
    }
}
