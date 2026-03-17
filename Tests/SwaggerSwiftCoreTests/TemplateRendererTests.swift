import Foundation
import Testing

@testable import SwaggerSwiftCore

@Suite
struct TemplateRendererTests {
    private static let testTemplatesURL: URL = {
        let thisFile = URL(fileURLWithPath: #filePath)
        return thisFile.deletingLastPathComponent()
            .appendingPathComponent("Fixtures")
            .appendingPathComponent("Templates")
    }()

    @Test func renderSimpleTemplate() throws {
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

        #expect(
            result
                == """
                public struct MyModel {

                    public let id: String

                    public let count: Int

                }

                """
        )
    }

    @Test func indentedFilter() throws {
        let renderer = TemplateRenderer(templateDirectory: Self.testTemplatesURL)
        let result = try renderer.render(
            template: "IndentedTest.stencil",
            context: [
                "body": "line1\nline2\n\nline4"
            ]
        )

        #expect(
            result
                == """
                wrapper {
                    line1
                    line2

                    line4
                }

                """
        )
    }
}
