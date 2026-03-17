import XCTest
import Yams

@testable import SwaggerSwiftML

final class ResponseTests: XCTestCase {
    func testResponse() {
        let basicFileUrl = Bundle.module.url(
            forResource: "Response/referenced_schema",
            withExtension: "yaml"
        )

        let fileContents = try! String(contentsOf: basicFileUrl!, encoding: .utf8)

        try! YAMLDecoder().decode([String: Response].self, from: fileContents)
    }

    func testResponseWithHeader() {
        let basicFileUrl = Bundle.module.url(
            forResource: "Response/response_with_header",
            withExtension: "yaml"
        )

        let fileContents = try! String(contentsOf: basicFileUrl!, encoding: .utf8)

        let result = try! YAMLDecoder().decode(Response.self, from: fileContents)

        let headers = result.headers
        XCTAssertNotNil(headers)
    }
}
