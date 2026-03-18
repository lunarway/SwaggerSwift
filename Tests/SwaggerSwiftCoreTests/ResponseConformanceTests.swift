import Foundation
import SwaggerSwiftML
import Testing

@testable import SwaggerSwiftCore

/// Tests that global response model definitions get correct Codable conformance.
///
/// When a swagger spec defines global `responses` that reference definitions,
/// those response models should be treated as decodable (not codable), because
/// they are only ever decoded from network responses, never encoded into requests.
///
/// Previously, response models that weren't directly referenced by API request/response
/// types would fall back to `Codable`, causing compile errors when they referenced
/// types that were correctly optimized to `Decodable`-only.
@Suite
struct ResponseConformanceTests {
    private let modelDefinitions: [ModelDefinition]

    init() throws {
        let specURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures")
            .appendingPathComponent("response_conformance_spec.json")
        let specString = try String(contentsOf: specURL, encoding: .utf8)

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

        let swagger = try SwaggerReader.read(text: specString)
        let (_, modelDefs) = try apiFactory.generate(
            for: swagger,
            withSwaggerFile: swaggerFile
        )

        self.modelDefinitions = modelDefs
    }

    private func findModel(_ typeName: String) -> Model? {
        modelDefinitions
            .compactMap { def -> Model? in
                if case .object(let model) = def { return model }
                return nil
            }
            .first(where: { $0.typeName == typeName })
    }

    // MARK: - Response-only models should be Decodable, not Codable

    @Test
    func itemIsDecodableOnly() throws {
        let item = try #require(findModel("Item"))
        #expect(item.isDecodable == true, "Item is used in GET/POST responses, should be Decodable")
        #expect(item.isEncodable == false, "Item is never sent as a request body, should not be Encodable")
    }

    @Test
    func itemDetailIsCodable() throws {
        let detail = try #require(findModel("ItemDetail"))
        #expect(detail.isDecodable == true, "ItemDetail is used in responses (via Item), should be Decodable")
        #expect(
            detail.isEncodable == true,
            "ItemDetail is used in request body (via CreateItemRequest), should be Encodable"
        )
    }

    // MARK: - Request-only models should be Encodable, not Codable

    @Test
    func createItemRequestIsEncodableOnly() throws {
        let request = try #require(findModel("CreateItemRequest"))
        #expect(request.isEncodable == true, "CreateItemRequest is a request body, should be Encodable")
        #expect(
            request.isDecodable == false,
            "CreateItemRequest is never decoded from responses, should not be Decodable"
        )
    }

    // MARK: - Response model definitions from global responses section

    @Test
    func errorModelIsDecodableOnly() throws {
        let error = try #require(findModel("ErrorModel"))
        #expect(
            error.isDecodable == true,
            "ErrorModel is referenced by global responses, should be Decodable"
        )
        #expect(
            error.isEncodable == false,
            "ErrorModel is only used in error responses, should not be Encodable"
        )
    }
}
