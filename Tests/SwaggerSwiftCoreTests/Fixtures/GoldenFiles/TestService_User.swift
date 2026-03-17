import Foundation

extension TestService {
    public struct User: Decodable, Sendable {
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
        // User tags
        public let tags: [String]?

        public init(avatarUrl: URL? = nil, email: String, id: String, metadata: [String: String]? = nil, name: String, role: TestService.UserRole, tags: [String]? = nil) {
            self.avatarUrl = avatarUrl
            self.email = email
            self.id = id
            self.metadata = metadata
            self.name = name
            self.role = role
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
            self.tags = try container.decodeIfPresent([String].self, forKey: "tags")
        }
    }
}
