import Foundation
import Testing

@testable import SwaggerSwiftCore

/// Focused tests for APIRequest template rendering.
///
/// Each test constructs an APIRequest directly and verifies the generated
/// Swift output covers specific code paths in the templates:
/// - APIRequestFunction.stencil (core async function body)
/// - APIRequest.stencil (outer wrappers: docs, #if DEBUG, @deprecated, completion handler)
@Suite
struct APIRequestTemplateTests {
    private let templateRenderer = TemplateRenderer()

    // MARK: - Helpers

    private func makeSwaggerFile(
        onlyAsync: Bool = true,
        globalHeaders: [String] = []
    ) -> SwaggerFile {
        SwaggerFile(
            path: "swagger.json",
            organisation: "test",
            services: [:],
            globalHeaders: globalHeaders,
            createSwiftPackage: false,
            accessControl: .public,
            destination: "./",
            projectName: "TestProject",
            onlyAsync: onlyAsync
        )
    }

    private func makeRequest(
        functionName: String = "doSomething",
        description: String? = nil,
        parameters: [FunctionParameter] = [],
        consumes: APIRequestConsumes = .json,
        isInternalOnly: Bool = false,
        isDeprecated: Bool = false,
        httpMethod: HTTPMethod = .get,
        servicePath: String = "/test",
        queries: [QueryElement] = [],
        headers: [APIRequestHeaderField] = [],
        responseTypes: [APIRequestResponseType] = [.void(.ok, false)],
        successType: TypeType = .void,
        failureType: TypeType = .object(typeName: "ServiceError<Void>")
    ) -> APIRequest {
        APIRequest(
            description: description,
            functionName: functionName,
            parameters: parameters,
            consumes: consumes,
            isInternalOnly: isInternalOnly,
            isDeprecated: isDeprecated,
            httpMethod: httpMethod,
            servicePath: servicePath,
            queries: queries,
            headers: headers,
            responseTypes: responseTypes,
            returnType: ReturnType(
                description: "",
                successType: successType,
                failureType: failureType
            )
        )
    }

    private func render(
        _ request: APIRequest,
        onlyAsync: Bool = true,
        globalHeaders: [String] = [],
        accessControl: String = "public"
    ) throws -> String {
        try request.toSwift(
            serviceName: "TestService",
            swaggerFile: makeSwaggerFile(onlyAsync: onlyAsync, globalHeaders: globalHeaders),
            embedded: false,
            accessControl: accessControl,
            packagesToImport: [],
            templateRenderer: templateRenderer
        )
    }

    // MARK: - onlyAsync: true (public function, no wrappers)

    @Test
    func onlyAsyncSimpleGetRendersPublicFunction() throws {
        let request = makeRequest()
        let output = try render(request, onlyAsync: true)

        #expect(output.contains("public func doSomething("))
        #expect(!output.contains("private func _doSomething("))
        #expect(!output.contains("completion:"))
        #expect(!output.contains("_Concurrency.Task"))
        #expect(!output.contains("@discardableResult"))
    }

    // MARK: - onlyAsync: false (wrappers generated)

    @Test
    func notOnlyAsyncRendersCompletionHandlerWrapper() throws {
        let request = makeRequest(
            responseTypes: [.object(.ok, false, typeName: "User")],
            successType: .object(typeName: "User"),
            failureType: .object(typeName: "ServiceError<Void>")
        )
        let output = try render(request, onlyAsync: false)

        // Private async function
        #expect(output.contains("private func _doSomething("))
        // Completion handler wrapper
        #expect(output.contains("completion: @Sendable @escaping (Result<User, ServiceError<Void>>)"))
        #expect(output.contains("_Concurrency.Task"))
        #expect(output.contains("let result = try await _doSomething("))
        #expect(output.contains("completion(.success(result))"))
        // Public async wrapper
        #expect(output.contains("public func doSomething("))
        #expect(output.contains("try await _doSomething("))
        // Non-void gets @discardableResult
        #expect(output.contains("@discardableResult"))
    }

    @Test
    func voidReturnWithWrappersUsesSuccessUnit() throws {
        let request = makeRequest(
            successType: .void,
            failureType: .object(typeName: "ServiceError<Void>")
        )
        let output = try render(request, onlyAsync: false)

        #expect(output.contains("completion(.success(()))"))
        #expect(!output.contains("let result = try await"))
        #expect(!output.contains("@discardableResult"))
    }

    // MARK: - isDeprecated

    @Test
    func deprecatedEndpointAddsAvailableAnnotation() throws {
        let request = makeRequest(isDeprecated: true)
        let output = try render(request, onlyAsync: true)

        #expect(output.contains("@available(*, deprecated)"))
    }

    @Test
    func deprecatedWithWrappersAnnotatesAllVariants() throws {
        let request = makeRequest(
            isDeprecated: true,
            responseTypes: [.object(.ok, false, typeName: "User")],
            successType: .object(typeName: "User"),
            failureType: .object(typeName: "ServiceError<Void>")
        )
        let output = try render(request, onlyAsync: false)

        // Should appear 3 times: before private func, before completion handler, before async wrapper
        let deprecatedCount = output.components(separatedBy: "@available(*, deprecated)").count - 1
        #expect(deprecatedCount == 3)
    }

    // MARK: - isInternalOnly

    @Test
    func internalOnlyWrapsInDebugDirective() throws {
        let request = makeRequest(isInternalOnly: true)
        let output = try render(request, onlyAsync: true)

        #expect(output.contains("#if DEBUG"))
        #expect(output.contains("#endif"))
        // Internal-only with onlyAsync should still use private func
        #expect(output.contains("private func _doSomething("))
    }

    @Test
    func internalOnlyWithWrappersIncludesAllInsideDebug() throws {
        let request = makeRequest(
            isInternalOnly: true,
            responseTypes: [.object(.ok, false, typeName: "User")],
            successType: .object(typeName: "User"),
            failureType: .object(typeName: "ServiceError<Void>")
        )
        let output = try render(request, onlyAsync: false)

        #expect(output.contains("#if DEBUG"))
        #expect(output.contains("#endif"))
        #expect(output.contains("private func _doSomething("))
        #expect(output.contains("completion:"))
    }

    // MARK: - Headers (per-endpoint)

    @Test
    func requiredHeaderSetsValueDirectly() throws {
        let request = makeRequest(
            headers: [
                APIRequestHeaderField(headerName: "X-Request-Id", isRequired: true)
            ]
        )
        let output = try render(request)

        #expect(output.contains("request.setValue(headers.requestId, forHTTPHeaderField: \"X-Request-Id\")"))
    }

    @Test
    func optionalHeaderWrapsInIfLet() throws {
        let request = makeRequest(
            headers: [
                APIRequestHeaderField(headerName: "X-Trace-Id", isRequired: false)
            ]
        )
        let output = try render(request)

        #expect(output.contains("if let traceId = headers?.traceId"))
        #expect(output.contains("forHTTPHeaderField: \"X-Trace-Id\""))
    }

    // MARK: - Global headers

    @Test
    func globalHeadersInjectsHeaderProvider() throws {
        let request = makeRequest()
        let output = try render(request, globalHeaders: ["Authorization"])

        #expect(output.contains("let globalHeaders = await self.headerProvider()"))
        #expect(output.contains("globalHeaders.add(to: &request)"))
    }

    // MARK: - Body injection (JSON)

    @Test
    func jsonBodyEncodesParameter() throws {
        let request = makeRequest(
            parameters: [
                FunctionParameter(
                    description: nil,
                    name: "body",
                    typeName: .object(typeName: "CreateRequest"),
                    required: true,
                    in: .body,
                    isEnum: false
                )
            ],
            httpMethod: .post
        )
        let output = try render(request)

        #expect(output.contains("let jsonEncoder = JSONEncoder()"))
        #expect(output.contains("jsonEncoder.dateEncodingStrategy = .iso8601"))
        #expect(output.contains("request.httpBody = try? jsonEncoder.encode(body)"))
        #expect(output.contains("request.setValue(\"application/json\", forHTTPHeaderField: \"Content-Type\")"))
    }

    // MARK: - Query items

    @Test
    func queryItemsGenerateUrlComponentsCode() throws {
        let request = makeRequest(
            queries: [
                QueryElement(fieldName: "limit", fieldValue: "limit", isOptional: true, valueType: .default)
            ]
        )
        let output = try render(request)

        #expect(output.contains("var urlComponents"))
        #expect(output.contains("var queryItems = [URLQueryItem]()"))
        #expect(output.contains("urlComponents.queryItems = queryItems"))
    }

    @Test
    func noQueryItemsUsesLetUrlComponents() throws {
        let request = makeRequest()
        let output = try render(request)

        #expect(output.contains("let urlComponents"))
        #expect(!output.contains("var urlComponents"))
        #expect(!output.contains("var queryItems"))
    }

    // MARK: - Path parameters

    @Test
    func pathParameterInterpolatesInUrl() throws {
        let request = makeRequest(
            parameters: [
                FunctionParameter(
                    description: "The user ID",
                    name: "userId",
                    typeName: .string(defaultValue: nil),
                    required: true,
                    in: .path,
                    isEnum: false
                )
            ],
            servicePath: "/users/{userId}"
        )
        let output = try render(request)

        #expect(output.contains("users/\\(userId)"))
    }

    // MARK: - Response types

    @Test
    func objectResponseIncludesDecodeHelper() throws {
        let request = makeRequest(
            responseTypes: [.object(.ok, false, typeName: "User")],
            successType: .object(typeName: "User"),
            failureType: .object(typeName: "ServiceError<Void>")
        )
        let output = try render(request)

        #expect(output.contains("func _decodeObject<T: Decodable>"))
        #expect(output.contains("try _decodeObject(User.self)"))
    }

    @Test
    func dataResponseOmitsDecodeHelper() throws {
        let request = makeRequest(
            responseTypes: [.object(.ok, false, typeName: "Data")],
            successType: .object(typeName: "Data"),
            failureType: .object(typeName: "ServiceError<Void>")
        )
        let output = try render(request)

        #expect(!output.contains("func _decodeObject"))
        #expect(output.contains("return data"))
    }

    @Test
    func voidResponseOmitsDecodeHelper() throws {
        let request = makeRequest(
            responseTypes: [.void(.ok, false)],
            successType: .void
        )
        let output = try render(request)

        #expect(!output.contains("func _decodeObject"))
    }

    @Test
    func errorResponseThrows() throws {
        let request = makeRequest(
            responseTypes: [
                .object(.ok, false, typeName: "User"),
                .object(.badRequest, true, typeName: "ErrorResponse"),
            ],
            successType: .object(typeName: "User"),
            failureType: .object(typeName: "ServiceError<ErrorResponse>")
        )
        let output = try render(request)

        #expect(output.contains("case 200:"))
        #expect(output.contains("return try _decodeObject(User.self)"))
        #expect(output.contains("case 400:"))
        #expect(output.contains("throw"))
    }

    // MARK: - Documentation

    @Test
    func documentationIncludesEndpointAndParameters() throws {
        let request = makeRequest(
            description: "Fetch a user by ID",
            parameters: [
                FunctionParameter(
                    description: "The user ID",
                    name: "userId",
                    typeName: .string(defaultValue: nil),
                    required: true,
                    in: .path,
                    isEnum: false
                )
            ],
            httpMethod: .get,
            servicePath: "/users/{userId}"
        )
        let output = try render(request)

        #expect(output.contains("/// Fetch a user by ID"))
        #expect(output.contains("/// - Endpoint: `GET /users/{userId}`"))
        #expect(output.contains("/// - Parameters:"))
        #expect(output.contains("///   - userId: The user ID"))
    }

    @Test
    func noDescriptionUsesPlaceholder() throws {
        let request = makeRequest(description: nil)
        let output = try render(request)

        #expect(output.contains("/// No description provided"))
    }

    // MARK: - HTTP methods

    @Test
    func httpMethodIsUppercased() throws {
        let request = makeRequest(httpMethod: .post)
        let output = try render(request)

        #expect(output.contains("request.httpMethod = \"POST\""))
    }

    @Test
    func deleteMethodRendersCorrectly() throws {
        let request = makeRequest(httpMethod: .delete)
        let output = try render(request)

        #expect(output.contains("request.httpMethod = \"DELETE\""))
    }

    // MARK: - Function arguments

    @Test
    func optionalParameterDefaultsToNil() throws {
        let request = makeRequest(
            parameters: [
                FunctionParameter(
                    description: nil,
                    name: "limit",
                    typeName: .int(defaultValue: nil),
                    required: false,
                    in: .query,
                    isEnum: false
                )
            ]
        )
        let output = try render(request)

        #expect(output.contains("limit: Int? = nil"))
    }

    @Test
    func requiredParameterHasNoDefault() throws {
        let request = makeRequest(
            parameters: [
                FunctionParameter(
                    description: nil,
                    name: "userId",
                    typeName: .string(defaultValue: nil),
                    required: true,
                    in: .path,
                    isEnum: false
                )
            ]
        )
        let output = try render(request)

        #expect(output.contains("userId: String)"))
        #expect(!output.contains("userId: String? = nil"))
    }
}
