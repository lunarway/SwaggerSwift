import XCTest

@testable import SwaggerSwiftCore

final class TemplateRendererTests: XCTestCase {
    func testRenderSimpleTemplate() throws {
        let renderer = TemplateRenderer()
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
        let renderer = TemplateRenderer()
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
