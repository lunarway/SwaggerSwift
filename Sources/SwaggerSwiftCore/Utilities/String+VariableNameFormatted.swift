import Foundation

extension String {
    var variableNameFormatted: String {
        split(separator: ".")
            .flatMap { $0.split(separator: "-") }
            .map { String($0).capitalizingFirstLetter() }
            .joined()
            .camelized
            .lowercasingFirst
    }
}
