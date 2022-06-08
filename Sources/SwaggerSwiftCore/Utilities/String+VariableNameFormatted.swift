import Foundation

extension String {
    var variableNameFormatted: String {
        if self.starts(with: "`") { // is this a safe keyword already?
            return self
        } else {
            return split(separator: ".")
                .flatMap { $0.split(separator: "-") }
                .map { String($0).capitalizingFirstLetter() }
                .joined()
                .camelized
                .lowercasingFirst
        }
    }
}
