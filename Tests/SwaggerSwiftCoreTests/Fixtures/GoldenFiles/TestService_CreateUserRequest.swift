import Foundation

extension TestService {
    public struct CreateUserRequest: Codable, Sendable {
        public let email: String
        public let name: String
        public let role: TestService.UserRole?

        public init(email: String, name: String, role: TestService.UserRole? = nil) {
            self.email = email
            self.name = name
            self.role = role
        }

        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: StringCodingKey.self)
            self.email = try container.decode(String.self, forKey: "email")
            self.name = try container.decode(String.self, forKey: "name")
            self.role = try container.decodeIfPresent(TestService.UserRole.self, forKey: "role")
        }

        public func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: StringCodingKey.self)
            try container.encode(email, forKey: "email")
            try container.encode(name, forKey: "name")
            try container.encodeIfPresent(role, forKey: "role")
        }
    }
}
