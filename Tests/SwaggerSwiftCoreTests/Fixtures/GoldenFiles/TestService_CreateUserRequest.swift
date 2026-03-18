import Foundation

extension TestService {
    public struct CreateUserRequest: Encodable, Sendable {
        public let email: String
        public let name: String
        public let role: TestService.UserRole?

        public init(email: String, name: String, role: TestService.UserRole? = nil) {
            self.email = email
            self.name = name
            self.role = role
        }

        public func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: StringCodingKey.self)
            try container.encode(email, forKey: "email")
            try container.encode(name, forKey: "name")
            try container.encodeIfPresent(role, forKey: "role")
        }
    }
}
