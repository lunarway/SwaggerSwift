import Foundation

// A test service for golden file testing
public struct TestService: APIInitialize {
    private let urlSession: @Sendable () async -> URLSession
    private let baseUrlProvider: @Sendable () async -> URL
    private let interceptor: (any NetworkInterceptor)?

    /// Create an instance of TestService
    /// - Parameters:
    ///   - urlSession: the underlying URLSession. This is an autoclosure to allow updated instances to come into this instance.
    ///   - baseUrlProvider: the block provider for the baseUrl of the service. The reason this is a block is that this enables automatically updating the network layer on backend environment change.
    ///   - interceptor: use this if you need to intercept overall requests
    public init(urlSession: @escaping @Sendable() async -> URLSession, baseUrlProvider: @escaping @Sendable() async -> URL, interceptor: (any NetworkInterceptor)? = nil) {
        self.urlSession = urlSession
        self.baseUrlProvider = baseUrlProvider
        self.interceptor = interceptor
    }

    private func _makeJSONDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom(dateDecodingStrategy)
        return decoder
    }

    private func _unknownStatusError(statusCode: Int, data: Data) -> NSError {
        let result = String(data: data, encoding: .utf8) ?? ""
        return NSError(
            domain: "TestService",
            code: statusCode,
            userInfo: [NSLocalizedDescriptionKey: result]
        )
    }

    /// No description provided
    /// - Endpoint: `POST /users`
    /// - Parameters:
    ///   - body: No description
    public func createUser(body: CreateUserRequest) async throws(ServiceError<ErrorResponse>) -> User {
        let endpointUrl = await baseUrlProvider().appendingPathComponent("users")

        let urlComponents = URLComponents(url: endpointUrl, resolvingAgainstBaseURL: true)!

        let requestUrl = urlComponents.url!
        var request = URLRequest(url: requestUrl)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let jsonEncoder = JSONEncoder()
        jsonEncoder.dateEncodingStrategy = .iso8601
        request.httpBody = try? jsonEncoder.encode(body)


        let data: Data
        let response: URLResponse
        let httpResponse: HTTPURLResponse
        do {
            (request, data, response, httpResponse) = try await performRequest(
                request: request,
                requestData: nil,
                urlSessionProvider: urlSession,
                interceptor: interceptor
            )
        } catch {
            throw .requestFailed(error: error)
        }

        let decoder = _makeJSONDecoder()

        func _decodeObject<T: Decodable>(_ type: T.Type) throws(ServiceError<ErrorResponse>) -> T {
            do {
                return try decoder.decode(T.self, from: data)
            } catch let error {
                interceptor?.networkFailedToParseObject(
                    urlRequest: request,
                    urlResponse: response,
                    data: data,
                    error: error
                )
                throw ServiceError<ErrorResponse>.requestFailed(error: error)
            }
        }


        switch httpResponse.statusCode {
        case 201:
            return try _decodeObject(User.self)
        case 400:
            throw ServiceError<ErrorResponse>.backendError(error: try _decodeObject(ErrorResponse.self))
        default:
            throw .requestFailed(error: _unknownStatusError(statusCode: httpResponse.statusCode, data: data))
        }
    }

    /// No description provided
    /// - Endpoint: `GET /users/{userId}`
    /// - Parameters:
    ///   - userId: The user ID
    public func getUser(userId: String) async throws(ServiceError<Void>) -> User {
        let endpointUrl = await baseUrlProvider().appendingPathComponent("users/\(userId)")

        let urlComponents = URLComponents(url: endpointUrl, resolvingAgainstBaseURL: true)!

        let requestUrl = urlComponents.url!
        var request = URLRequest(url: requestUrl)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")


        let data: Data
        let response: URLResponse
        let httpResponse: HTTPURLResponse
        do {
            (request, data, response, httpResponse) = try await performRequest(
                request: request,
                requestData: nil,
                urlSessionProvider: urlSession,
                interceptor: interceptor
            )
        } catch {
            throw .requestFailed(error: error)
        }

        let decoder = _makeJSONDecoder()

        func _decodeObject<T: Decodable>(_ type: T.Type) throws(ServiceError<Void>) -> T {
            do {
                return try decoder.decode(T.self, from: data)
            } catch let error {
                interceptor?.networkFailedToParseObject(
                    urlRequest: request,
                    urlResponse: response,
                    data: data,
                    error: error
                )
                throw ServiceError<Void>.requestFailed(error: error)
            }
        }


        switch httpResponse.statusCode {
        case 200:
            return try _decodeObject(User.self)
        case 404:
            throw ServiceError<Void>.backendError(error: ())
        default:
            throw .requestFailed(error: _unknownStatusError(statusCode: httpResponse.statusCode, data: data))
        }
    }

    /// No description provided
    /// - Endpoint: `GET /users`
    /// - Parameters:
    ///   - limit: Maximum number of users to return
    ///   - offset: Number of users to skip
    public func getUsers(limit: Int? = nil, offset: Int? = nil) async throws(ServiceError<ErrorResponse>) -> [TestService.User] {
        let endpointUrl = await baseUrlProvider().appendingPathComponent("users")

        var urlComponents = URLComponents(url: endpointUrl, resolvingAgainstBaseURL: true)!
        var queryItems = [URLQueryItem]()
        if let limitValue = limit {
            queryItems.append(URLQueryItem(name: "limit", value: limitValue))
        }
        if let offsetValue = offset {
            queryItems.append(URLQueryItem(name: "offset", value: offsetValue))
        }
        urlComponents.queryItems = queryItems
        let requestUrl = urlComponents.url!
        var request = URLRequest(url: requestUrl)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")


        let data: Data
        let response: URLResponse
        let httpResponse: HTTPURLResponse
        do {
            (request, data, response, httpResponse) = try await performRequest(
                request: request,
                requestData: nil,
                urlSessionProvider: urlSession,
                interceptor: interceptor
            )
        } catch {
            throw .requestFailed(error: error)
        }

        let decoder = _makeJSONDecoder()

        func _decodeObject<T: Decodable>(_ type: T.Type) throws(ServiceError<ErrorResponse>) -> T {
            do {
                return try decoder.decode(T.self, from: data)
            } catch let error {
                interceptor?.networkFailedToParseObject(
                    urlRequest: request,
                    urlResponse: response,
                    data: data,
                    error: error
                )
                throw ServiceError<ErrorResponse>.requestFailed(error: error)
            }
        }


        switch httpResponse.statusCode {
        case 200:
            let result: [TestService.User]
            do {
                result = try decoder.decode([TestService.User].self, from: data)
            } catch let error {
                throw ServiceError<ErrorResponse>.requestFailed(error: error)
            }
            return result
        case 400:
            throw ServiceError<ErrorResponse>.backendError(error: try _decodeObject(ErrorResponse.self))
        default:
            throw .requestFailed(error: _unknownStatusError(statusCode: httpResponse.statusCode, data: data))
        }
    }
}
