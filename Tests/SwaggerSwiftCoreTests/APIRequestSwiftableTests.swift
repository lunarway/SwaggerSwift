import XCTest

@testable import SwaggerSwiftCore

final class APIRequestSwiftableTests: XCTestCase {
    func testGeneratedRequestFunctionAvoidsForceUnwrapsAndFatalError() {
        let apiRequest = makeAPIRequest()

        let generated = apiRequest.toSwift(
            serviceName: "TestService",
            swaggerFile: makeSwaggerFile(onlyAsync: false),
            embedded: false,
            accessControl: "public",
            packagesToImport: []
        )

        XCTAssertFalse(generated.contains("URLComponents(url: endpointUrl, resolvingAgainstBaseURL: true)!"))
        XCTAssertFalse(generated.contains("let requestUrl = urlComponents.url!"))
        XCTAssertFalse(generated.contains("fatalError(\"The response must be a URL response\")"))

        XCTAssertTrue(generated.contains("guard var urlComponents = URLComponents(url: endpointUrl, resolvingAgainstBaseURL: true) else"))
        XCTAssertTrue(generated.contains("guard let requestUrl = urlComponents.url else"))
        XCTAssertTrue(generated.contains("throw .requestFailed(error: URLError(.badServerResponse))"))
    }

    func testGeneratedCompletionBasedFunctionAvoidsForceCast() {
        let apiRequest = makeAPIRequest()

        let generated = apiRequest.toSwift(
            serviceName: "TestService",
            swaggerFile: makeSwaggerFile(onlyAsync: false),
            embedded: false,
            accessControl: "public",
            packagesToImport: []
        )

        XCTAssertFalse(generated.contains("as! ServiceError<TestServiceError>"))
        XCTAssertTrue(generated.contains("if let error = error as? ServiceError<TestServiceError>"))
        XCTAssertTrue(generated.contains("completion(.failure(.requestFailed(error: error)))"))
    }

    private func makeAPIRequest() -> APIRequest {
        APIRequest(
            description: "No description",
            functionName: "fetchSomething",
            parameters: [],
            consumes: .json,
            isInternalOnly: false,
            isDeprecated: false,
            httpMethod: .get,
            servicePath: "/v1/something",
            queries: [],
            headers: [],
            responseTypes: [.void(.ok, false)],
            returnType: ReturnType(
                description: "",
                successType: .void,
                failureType: .object(typeName: "ServiceError<TestServiceError>")
            )
        )
    }

    private func makeSwaggerFile(onlyAsync: Bool) -> SwaggerFile {
        SwaggerFile(
            path: "",
            organisation: "",
            services: [:],
            createSwiftPackage: false,
            accessControl: .public,
            destination: "./",
            projectName: "Services",
            onlyAsync: onlyAsync
        )
    }
}
