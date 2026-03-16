import XCTest

@testable import SwaggerSwiftCore

final class TemplateRendererTests: XCTestCase {
    private static let testTemplatesURL: URL = {
        let thisFile = URL(fileURLWithPath: #filePath)
        return thisFile.deletingLastPathComponent()
            .appendingPathComponent("Fixtures")
            .appendingPathComponent("Templates")
    }()

    func testRenderSimpleTemplate() throws {
        let renderer = TemplateRenderer(templateDirectory: Self.testTemplatesURL)
        let result = try renderer.render(
            template: "Test.stencil",
            context: [
                "accessControl": "public",
                "typeName": "MyModel",
                "fields": [
                    ["name": "id", "type": "String"],
                    ["name": "count", "type": "Int"],
                ],
            ]
        )

        XCTAssertEqual(
            result,
            """
            public struct MyModel {

                public let id: String

                public let count: Int

            }

            """
        )
    }

    func testIndentedFilter() throws {
        let renderer = TemplateRenderer(templateDirectory: Self.testTemplatesURL)
        let result = try renderer.render(
            template: "IndentedTest.stencil",
            context: [
                "body": "line1\nline2\n\nline4"
            ]
        )

        XCTAssertEqual(
            result,
            """
            wrapper {
                line1
                line2

                line4
            }

            """
        )
    }
}
