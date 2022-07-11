import Foundation

enum BooleanResolver {
    static func resolve(with defaultValue: Bool?) -> TypeType {
        return .boolean(defaultValue: defaultValue)
    }
}
