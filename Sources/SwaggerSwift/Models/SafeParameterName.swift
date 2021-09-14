import Foundation

struct SafeParameterName: Equatable, Hashable {
    let value: String

    init(_ parameterName: String) {
        if SwiftKeyword(rawValue: parameterName) != nil {
            value = "_swaggerswift_" + parameterName
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
