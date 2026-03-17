import XCTest

@testable import SwaggerSwiftML

final class SwaggerParseBasicFile: XCTestCase {
    static var fileContents: String!
    override class func setUp() {
        let basicFileUrl = Bundle.module.url(forResource: "BasicSwagger", withExtension: "yaml")

        fileContents = try! String(contentsOf: basicFileUrl!, encoding: .utf8)
    }

    func testParseBasicFile() {
        let swagger = try? SwaggerReader.read(text: SwaggerParseBasicFile.fileContents)
        XCTAssertNotNil(swagger)
    }

    func testExample() {
        let swagger = try! SwaggerReader.read(text: SwaggerParseBasicFile.fileContents)

        XCTAssertEqual(swagger.info.title, "Sample API")
    }

    static var allTests = [
        ("testExample", testExample)
    ]
}
