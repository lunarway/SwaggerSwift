import Foundation

struct SafeParameterName: Equatable, Hashable {
    let value: String

    init(_ parameterName: String) {
        if let keyword = SwiftKeyword(rawValue: parameterName) {
            value = keyword.safePropertyName
        } else {
            value = parameterName
        }
    }
}

extension SafeParameterName: CustomStringConvertible {
    var description: String {
        return value
    }
}

extension SafeParameterName: CustomDebugStringConvertible {
    var debugDescription: String {
        return value
    }
}

extension SafeParameterName: Comparable {
    static func < (lhs: SafeParameterName, rhs: SafeParameterName) -> Bool {
        return lhs.value < rhs.value
    }
}
