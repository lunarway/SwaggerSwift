import SwaggerSwiftML
import XCTest

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
final class GoldenFileTests: XCTestCase {
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

    private var swagger: Swagger!
    private var apiDefinition: APIDefinition!
    private var modelDefinitions: [ModelDefinition]!
    private var templateRenderer: TemplateRenderer!

    override func setUp() async throws {
        let specURL = Self.fixturesURL.appendingPathComponent("test_spec.json")
        let specData = try Data(contentsOf: specURL)
        let specString = String(data: specData, encoding: .utf8)!

        swagger = try SwaggerReader.read(text: specString)

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

        let swaggerFile = SwaggerFile(
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

        let (apiDef, modelDefs) = try apiFactory.generate(
            for: swagger,
            withSwaggerFile: swaggerFile
        )

        self.apiDefinition = apiDef
        self.modelDefinitions = modelDefs
        self.templateRenderer = TemplateRenderer()
    }

    // MARK: - API Definition

    func testAPIDefinitionGoldenFile() throws {
        let swaggerFile = SwaggerFile(
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

    func testModelDefinitionsGoldenFiles() throws {
        let sortedModels = modelDefinitions.sorted(by: { $0.typeName < $1.typeName })

        for model in sortedModels {
            let output = model.toSwift(
                serviceName: apiDefinition.serviceName,
                embedded: false,
                accessControl: .public,
                packagesToImport: [],
                templateRenderer: templateRenderer
            )

            let filename = "TestService_\(model.typeName).swift"
            try assertGoldenFile(named: filename, actual: output)
        }
    }

    // MARK: - Helpers

    private func assertGoldenFile(
        named filename: String,
        actual: String,
        file: StaticString = #filePath,
        line: UInt = #line
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
            XCTFail(
                "Golden file '\(filename)' not found. Run with UPDATE_GOLDEN_FILES=1 to create it.",
                file: file,
                line: line
            )
            return
        }

        let expected = try String(contentsOf: goldenURL, encoding: .utf8)

        if actual != expected {
            // Show a useful diff
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

            XCTFail(diffMessage, file: file, line: line)
        }
    }
}
