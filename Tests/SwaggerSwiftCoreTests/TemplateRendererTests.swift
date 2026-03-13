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
            template: "Test.stencil",
            context: [
                "accessControl": "internal",
                "typeName": "Inner",
                "fields": [
                    ["name": "value", "type": "Bool"]
                ],
            ]
        )

        XCTAssertTrue(result.contains("internal struct Inner"))
        XCTAssertTrue(result.contains("internal let value: Bool"))
    }
}
