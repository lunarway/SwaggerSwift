import XCTest
@testable import SwaggerSwiftCore

final class SwaggerSwiftTests: XCTestCase {

    let swaggerFile = SwaggerFile(path: "", organisation: "", services: [:], globalHeaders: nil)

    func testOptionalURLDecodeFormat() {

        let model = Model(description: nil,
                          typeName: "Test",
                          fields: [.init(description: nil, type: .object(typeName: "URL"), name: "url", required: false)],
                          inheritsFrom: [],
                          isInternalOnly: false,
                          embeddedDefinitions: [],
                          isCodable: true)

        let result = model.modelDefinition(serviceName: nil,
                                           swaggerFile: swaggerFile)

        XCTAssertEqual(result, """
public struct Test: Codable {
    public let url: URL?

    public init(url: URL?) {
        self.url = url
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // Allows the backend to return badly formatted urls
        if let urlString = try container.decodeIfPresent(String.self, forKey: .url) {
            self.url = URL(string: urlString)
        } else {
            self.url = nil
        }
    }
}
""")
    }

    func testURLDecodeFormat() {

        let model = Model(description: nil,
                          typeName: "Test",
                          fields: [.init(description: nil, type: .object(typeName: "URL"), name: "url", required: true)],
                          inheritsFrom: [],
                          isInternalOnly: false,
                          embeddedDefinitions: [],
                          isCodable: true)

        let result = model.modelDefinition(serviceName: nil,
                                           swaggerFile: swaggerFile)

        XCTAssertEqual(result, """
public struct Test: Codable {
    public let url: URL

    public init(url: URL) {
        self.url = url
    }
}
""")
    }

    static var allTests = [
        ("testOptionalURLDecodeFormat", testOptionalURLDecodeFormat),
        ("testURLDecodeFormat", testURLDecodeFormat)
    ]
}
