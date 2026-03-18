

extension TestService {
    public enum UserRole: Codable, Equatable, Sendable {
        case admin
        case guest
        case user
        case unknown(String)


        public init(from decoder: any Decoder) throws {
            let container = try decoder.singleValueContainer()
            let stringValue = try container.decode(String.self)
            switch stringValue {
            case "admin": self = .admin
            case "guest": self = .guest
            case "user": self = .user
            default:
                self = .unknown(stringValue)
            }
        }

        public func encode(to encoder: any Encoder) throws {
            var container = encoder.singleValueContainer()
            switch self {
            case .admin:
                try container.encode("admin")
            case .guest:
                try container.encode("guest")
            case .user:
                try container.encode("user")
            case .unknown(let stringValue):
                try container.encode(stringValue)
            }
        }

        public init(rawValue: String) {
            switch rawValue {
            case "admin": self = .admin
            case "guest": self = .guest
            case "user": self = .user
            default:
                self = .unknown(rawValue)
            }
        }

        public var rawValue: String {
            switch self {
            case .admin:
                return "admin"
            case .guest:
                return "guest"
            case .user:
                return "user"
            case .unknown(let stringValue):
                return stringValue
            }
        }
    }
}
