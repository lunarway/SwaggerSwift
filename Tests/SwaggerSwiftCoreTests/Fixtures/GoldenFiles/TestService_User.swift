import Foundation

extension TestService {
    public struct User: Codable, Sendable {
        // Avatar URL
        public let avatarUrl: URL?
        // Email address
        public let email: String
        // Unique identifier
        public let id: String
        // Arbitrary metadata
        public let metadata: [String: String]?
        // Full name
        public let name: String
        public let role: TestService.UserRole
        // Account status
        public let status: Status?
        // User tags
        public let tags: [String]?

        public init(avatarUrl: URL? = nil, email: String, id: String, metadata: [String: String]? = nil, name: String, role: TestService.UserRole, status: Status? = nil, tags: [String]? = nil) {
            self.avatarUrl = avatarUrl
            self.email = email
            self.id = id
            self.metadata = metadata
            self.name = name
            self.role = role
            self.status = status
            self.tags = tags
        }

        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: StringCodingKey.self)
            // Allows the backend to return badly formatted urls
            if let urlString = try container.decodeIfPresent(String.self, forKey: "avatarUrl") {
                self.avatarUrl = URL(string: urlString)
            } else {
                self.avatarUrl = nil
            }
            self.email = try container.decode(String.self, forKey: "email")
            self.id = try container.decode(String.self, forKey: "id")
            self.metadata = try container.decodeIfPresent([String: String].self, forKey: "metadata")
            self.name = try container.decode(String.self, forKey: "name")
            self.role = try container.decode(TestService.UserRole.self, forKey: "role")
            self.status = try container.decodeIfPresent(Status.self, forKey: "status")
            self.tags = try container.decodeIfPresent([String].self, forKey: "tags")
        }

        public func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: StringCodingKey.self)
            try container.encodeIfPresent(avatarUrl, forKey: "avatarUrl")
            try container.encode(email, forKey: "email")
            try container.encode(id, forKey: "id")
            try container.encodeIfPresent(metadata, forKey: "metadata")
            try container.encode(name, forKey: "name")
            try container.encode(role, forKey: "role")
            try container.encodeIfPresent(status, forKey: "status")
            try container.encodeIfPresent(tags, forKey: "tags")
        }

        public enum Status: Codable, Equatable, Sendable {
            case active
            case inactive
            case suspended
            case unknown(String)


            public init(from decoder: any Decoder) throws {
                let container = try decoder.singleValueContainer()
                let stringValue = try container.decode(String.self)
                switch stringValue {
                case "active": self = .active
                case "inactive": self = .inactive
                case "suspended": self = .suspended
                default:
                    self = .unknown(stringValue)
                }
            }

            public func encode(to encoder: any Encoder) throws {
                var container = encoder.singleValueContainer()
                switch self {
                case .active:
                    try container.encode("active")
                case .inactive:
                    try container.encode("inactive")
                case .suspended:
                    try container.encode("suspended")
                case .unknown(let stringValue):
                    try container.encode(stringValue)
                }
            }

            public init(rawValue: String) {
                switch rawValue {
                case "active": self = .active
                case "inactive": self = .inactive
                case "suspended": self = .suspended
                default:
                    self = .unknown(rawValue)
                }
            }

            public var rawValue: String {
                switch self {
                case .active:
                    return "active"
                case .inactive:
                    return "inactive"
                case .suspended:
                    return "suspended"
                case .unknown(let stringValue):
                    return stringValue
                }
            }
        }
    }
}
