import Foundation
import SwaggerSwiftML
import Testing

@testable import SwaggerSwiftCore

@Suite
struct IgnoredPathsTests {
    private static let specURL: URL = {
        let thisFile = URL(fileURLWithPath: #filePath)
        return thisFile.deletingLastPathComponent()
            .appendingPathComponent("Fixtures")
            .appendingPathComponent("test_spec.json")
    }()

    private let apiFactory: APIFactory

    init() {
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

        self.apiFactory = APIFactory(
            apiRequestFactory: apiRequestFactory,
            modelTypeResolver: modelTypeResolver
        )
    }

    private func generateAPI(ignoredPaths: [String]) throws -> APIDefinition {
        let specData = try Data(contentsOf: Self.specURL)
        let specString = String(data: specData, encoding: .utf8)!
        let swagger = try SwaggerReader.read(text: specString)

        let swaggerFile = SwaggerFile(
            path: "swagger.json",
            organisation: "test",
            services: [:],
            ignoredPaths: ignoredPaths,
            accessControl: .public,
            projectName: "TestProject",
            onlyAsync: true
        )

        let (apiDefinition, _) = try apiFactory.generate(
            for: swagger,
            withSwaggerFile: swaggerFile
        )

        return apiDefinition
    }

    @Test
    func noIgnoredPathsGeneratesAllEndpoints() throws {
        let api = try generateAPI(ignoredPaths: [])
        let functionNames = api.functions.map(\.functionName).sorted()
        #expect(functionNames == ["createUser", "getUser", "getUsers"])
    }

    @Test
    func ignoredPathExcludesAllMethodsOnThatPath() throws {
        // /users has both GET and POST — ignoring it should remove both
        let api = try generateAPI(ignoredPaths: ["/users"])
        let functionNames = api.functions.map(\.functionName).sorted()
        #expect(functionNames == ["getUser"])
    }

    @Test
    func ignoredPathDoesNotAffectOtherPaths() throws {
        let api = try generateAPI(ignoredPaths: ["/users/{userId}"])
        let functionNames = api.functions.map(\.functionName).sorted()
        #expect(functionNames == ["createUser", "getUsers"])
    }

    @Test
    func multipleIgnoredPathsAreAllExcluded() throws {
        let api = try generateAPI(ignoredPaths: ["/users", "/users/{userId}"])
        #expect(api.functions.isEmpty)
    }
}
