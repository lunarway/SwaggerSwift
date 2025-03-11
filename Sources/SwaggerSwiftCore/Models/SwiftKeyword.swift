import Foundation

/// The SwiftKeyword type is used when ensuring that properties and parameters don't have the same name as a keyword.
/// The list is not complete.
enum SwiftKeyword: String {
    case kContinue = "continue"
    case kOperator = "operator"
    case kSelf = "self"
    case kPrivate = "private"
    case kPublic = "public"
    case kThrow = "throw"
    case kThrows = "throws"
    case kOverride = "override"
    case kDefault = "default"
    case kDefer = "defer"

    var safePropertyName: String {
        switch self {
        case .kContinue:
            return "`continue`"
        case .kOperator:
            return "`operator`"
        case .kSelf:
            return "this"
        case .kPrivate:
            return "isPrivate"
        case .kPublic:
            return "isPublic"
        case .kThrow:
            return "`throw`"
        case .kThrows:
            return "`throws`"
        case .kOverride:
            return "isOverride"
        case .kDefault:
            return "isDefault"
        case .kDefer:
            return "`defer`"
        }
    }
}
