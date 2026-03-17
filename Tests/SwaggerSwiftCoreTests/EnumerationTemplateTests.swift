import Testing

@testable import SwaggerSwiftCore

@Suite
struct EnumerationTemplateTests {
    private let templateRenderer = TemplateRenderer()

    @Test
    func embeddedEnumerationDoesNotIncludeTrailingNewline() throws {
        let enumeration = Enumeration(
            serviceName: nil,
            description: nil,
            typeName: "ExampleEnum",
            values: ["value"],
            isCodable: false,
            collectionFormat: nil
        )

        let output = try enumeration.toSwift(
            serviceName: nil,
            embedded: true,
            accessControl: .public,
            packagesToImport: [],
            templateRenderer: templateRenderer
        )

        #expect(
            output == """
                public enum ExampleEnum: Sendable {
                    case value
                }
                """
        )
    }

    @Test
    func importsAndExtensionAreSeparatedBySingleBlankLine() throws {
        let enumeration = Enumeration(
            serviceName: "MyService",
            description: nil,
            typeName: "ExampleEnum",
            values: ["value"],
            isCodable: false,
            collectionFormat: nil
        )

        let output = try enumeration.toSwift(
            serviceName: "MyService",
            embedded: false,
            accessControl: .public,
            packagesToImport: ["SharedKit"],
            templateRenderer: templateRenderer
        )

        #expect(output.contains("import SharedKit\n\nextension MyService {"))
        #expect(!output.contains("import SharedKit\n\n\nextension MyService {"))
    }

    @Test
    func multilineDescriptionCommentIsIndentedInsideExtension() throws {
        let enumeration = Enumeration(
            serviceName: "MyService",
            description: "First line\nSecond line",
            typeName: "ExampleEnum",
            values: ["value"],
            isCodable: false,
            collectionFormat: nil
        )

        let output = try enumeration.toSwift(
            serviceName: "MyService",
            embedded: false,
            accessControl: .public,
            packagesToImport: [],
            templateRenderer: templateRenderer
        )

        #expect(output.contains("    // First line\n    // Second line\n"))
        #expect(!output.contains("\n// Second line\n"))
    }
}
