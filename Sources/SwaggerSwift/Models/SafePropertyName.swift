import Foundation

struct SafePropertyName: Equatable, Hashable {
    let value: String

    init(_ propertyName: String) {
        if SwiftKeyword(rawValue: propertyName) != nil {
            value = "`" + propertyName + "`"
        } else {
            value = propertyName
        }
    }
}

extension SafePropertyName: CustomStringConvertible {
    var description: String {
        return value
    }
}

extension SafePropertyName: CustomDebugStringConvertible {
    var debugDescription: String {
        return value
    }
}

extension SafePropertyName: Comparable {
    static func < (lhs: SafePropertyName, rhs: SafePropertyName) -> Bool {
        return lhs.value < rhs.value
    }
}
