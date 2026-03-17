import Foundation
import SwaggerSwiftML
import Testing

@testable import SwaggerSwiftCore

/// Golden file tests that snapshot the generated Swift output.
///
/// These tests parse a representative Swagger spec, generate Swift code using
/// the current code generation pipeline, and compare the output byte-for-byte
/// against stored golden files.
///
/// ## Updating golden files
///
/// When you intentionally change code generation output, run:
/// ```
/// UPDATE_GOLDEN_FILES=1 swift test --filter GoldenFileTests
/// ```
/// Then review and commit the updated golden files.
@Suite
struct GoldenFileTests {
    private static let fixturesURL: URL = {
        let thisFile = URL(fileURLWithPath: #filePath)
        return thisFile.deletingLastPathComponent().appendingPathComponent("Fixtures")
    }()

    private static let goldenFilesURL: URL = {
        fixturesURL.appendingPathComponent("GoldenFiles")
    }()

    private static let shouldUpdate: Bool = {
        ProcessInfo.processInfo.environment["UPDATE_GOLDEN_FILES"] == "1"
    }()

    private let swaggerFile: SwaggerFile
    private let apiDefinition: APIDefinition
    private let modelDefinitions: [ModelDefinition]
    private let templateRenderer: TemplateRenderer

    init() throws {
        let specURL = Self.fixturesURL.appendingPathComponent("test_spec.json")
        let specData = try Data(contentsOf: specURL)
        let specString = String(data: specData, encoding: .utf8)!

        let objectModelFactory = ObjectModelFactory()
        let modelTypeResolver = ModelTypeResolver(objectModelFactory: objectModelFactory)
        objectModelFactory.modelTypeResolver = modelTypeResolver
        let apiResponseTypeFactory = APIResponseTypeFactory()
        let requestParameterFactory = RequestParameterFactory(modelTypeResolver: modelTypeResolver)
        let apiRequestFactory = APIRequestFactory(
            apiResponseTypeFactory: apiResponseTypeFactory,
            requestParameterFactory: requestParameterFactory,
            modelTypeResolver: modelTypeResolver
        )

        let apiFactory = APIFactory(
            apiRequestFactory: apiRequestFactory,
            modelTypeResolver: modelTypeResolver
        )

        self.swaggerFile = SwaggerFile(
            path: "swagger.json",
            organisation: "test",
            services: [:],
            globalHeaders: [],
            createSwiftPackage: false,
            accessControl: .public,
            destination: "./",
            projectName: "TestProject",
            onlyAsync: true
        )

        let swagger = try SwaggerReader.read(text: specString)
        let (apiDef, modelDefs) = try apiFactory.generate(
            for: swagger,
            withSwaggerFile: swaggerFile
        )

        self.apiDefinition = apiDef
        self.modelDefinitions = modelDefs
        self.templateRenderer = TemplateRenderer()
    }

    // MARK: - API Definition

    @Test
    func apiDefinitionGoldenFile() throws {
        let output = apiDefinition.toSwift(
            swaggerFile: swaggerFile,
            accessControl: "public",
            packagesToImport: []
        )

        try assertGoldenFile(
            named: "TestService.swift",
            actual: output
        )
    }

    // MARK: - Model Definitions

    @Test(arguments: [
        "CreateUserRequest",
        "ErrorResponse",
        "User",
        "UserId",
        "UserList",
        "UserRole",
    ])
    func modelDefinitionGoldenFile(typeName: String) throws {
        guard let model = modelDefinitions.first(where: { $0.typeName == typeName }) else {
            Issue.record("Model '\(typeName)' not found in generated definitions")
            return
        }

        let output = try model.toSwift(
            serviceName: apiDefinition.serviceName,
            embedded: false,
            accessControl: .public,
            packagesToImport: [],
            templateRenderer: templateRenderer
        )

        let filename = "TestService_\(typeName).swift"
        try assertGoldenFile(named: filename, actual: output)
    }

    // MARK: - Helpers

    private func assertGoldenFile(
        named filename: String,
        actual: String,
        sourceLocation: SourceLocation = #_sourceLocation
    ) throws {
        let goldenURL = Self.goldenFilesURL.appendingPathComponent(filename)

        if Self.shouldUpdate {
            try FileManager.default.createDirectory(
                at: Self.goldenFilesURL,
                withIntermediateDirectories: true
            )
            try actual.write(to: goldenURL, atomically: true, encoding: .utf8)
            return
        }

        guard FileManager.default.fileExists(atPath: goldenURL.path) else {
            Issue.record(
                "Golden file '\(filename)' not found. Run with UPDATE_GOLDEN_FILES=1 to create it.",
                sourceLocation: sourceLocation
            )
            return
        }

        let expected = try String(contentsOf: goldenURL, encoding: .utf8)

        if actual != expected {
            let actualLines = actual.split(separator: "\n", omittingEmptySubsequences: false)
            let expectedLines = expected.split(separator: "\n", omittingEmptySubsequences: false)

            var diffMessage = "Golden file '\(filename)' does not match.\n"
            let maxLines = max(actualLines.count, expectedLines.count)
            for i in 0..<maxLines {
                let actualLine = i < actualLines.count ? String(actualLines[i]) : "<missing>"
                let expectedLine = i < expectedLines.count ? String(expectedLines[i]) : "<missing>"
                if actualLine != expectedLine {
                    diffMessage += "  Line \(i + 1):\n"
                    diffMessage += "    expected: \(expectedLine)\n"
                    diffMessage += "    actual:   \(actualLine)\n"
                }
            }
            diffMessage += "\nRun with UPDATE_GOLDEN_FILES=1 to update."

            Issue.record(Comment(rawValue: diffMessage), sourceLocation: sourceLocation)
        }
    }
}
