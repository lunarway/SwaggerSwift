import Foundation

extension TestService {
    public struct ErrorResponse: Codable, Sendable {
        public let code: Int
        public let message: String

        public init(code: Int, message: String) {
            self.code = code
            self.message = message
        }

        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: StringCodingKey.self)
            self.code = try container.decode(Int.self, forKey: "code")
            self.message = try container.decode(String.self, forKey: "message")
        }

        public func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: StringCodingKey.self)
            try container.encode(code, forKey: "code")
            try container.encode(message, forKey: "message")
        }
    }
}