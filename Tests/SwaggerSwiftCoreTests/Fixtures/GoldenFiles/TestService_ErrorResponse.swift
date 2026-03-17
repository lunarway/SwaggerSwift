import Foundation

extension TestService {
    public struct ErrorResponse: Decodable, Sendable {
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
    }
}
