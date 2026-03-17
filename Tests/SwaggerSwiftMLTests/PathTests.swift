import XCTest
import Yams

@testable import SwaggerSwiftML

final class PathTests: XCTestCase {
    func testParseArrayParameter() {
        let basicFileUrl = Bundle.module.url(forResource: "Path/post_path", withExtension: "yaml")

        let fileContents = try! String(contentsOf: basicFileUrl!, encoding: .utf8)

        let path = try! YAMLDecoder().decode(Path.self, from: fileContents)
        guard let post = path.post else {
            XCTAssert(false, "Failed to parse post operation")
            return
        }

        XCTAssertEqual(post.parameters![0].unwrapped!.name, "data")
    }
}
