import XCTest
import Yams

@testable import SwaggerSwiftML

final class OperationTests: XCTestCase {
    func testParseCustomFields() {
        let basicFileUrl = Bundle.module.url(
            forResource: "Operation/customFields",
            withExtension: "yaml"
        )

        let fileContents = try! String(contentsOf: basicFileUrl!, encoding: .utf8)

        let operation = try! YAMLDecoder().decode(Operation.self, from: fileContents)

        XCTAssertEqual(operation.customFields["x-internal"], "true")
    }

    func testSupportsEmptyResponse() {
        let basicFileUrl = Bundle.module.url(
            forResource: "Operation/empty_response",
            withExtension: "yaml"
        )

        let fileContents = try! String(contentsOf: basicFileUrl!, encoding: .utf8)

        _ = try! YAMLDecoder().decode(Operation.self, from: fileContents)
    }
}
