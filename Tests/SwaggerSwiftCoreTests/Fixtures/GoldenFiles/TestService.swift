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

    private func _performRequest(request: URLRequest, requestData: Data?) async throws -> (Data, URLResponse, HTTPURLResponse) {
        let request = interceptor?.networkWillPerformRequest(request) ?? request

        let data: Data
        let response: URLResponse
        do {
            if let requestData {
                (data, response) = try await urlSession().upload(for: request, from: requestData)
            } else {
                (data, response) = try await urlSession().data(for: request)
            }
        } catch {
            throw error
        }

        if let interceptor {
            try await interceptor.networkDidPerformRequest(
                urlRequest: request,
                urlResponse: response,
                data: data,
                error: nil
            )
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            fatalError("The response must be a URL response")
        }

        return (data, response, httpResponse)
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
            (data, response, httpResponse) = try await performRequest(
                request: request,
                requestData: nil,
                urlSessionProvider: urlSession,
                interceptor: interceptor
            )
        } catch {
            throw .requestFailed(error: error)
        }

        let decoder = _makeJSONDecoder()

        switch httpResponse.statusCode {
        case 201:
            let result: User
            do {
                result = try decoder.decode(User.self, from: data)
            } catch let error {
                interceptor?.networkFailedToParseObject(
                    urlRequest: request,
                    urlResponse: response,
                    data: data,
                    error: error
                )
                throw ServiceError<ErrorResponse>.requestFailed(error: error)
            }
                return result
        case 400:
            let result: ErrorResponse
            do {
                result = try decoder.decode(ErrorResponse.self, from: data)
            } catch let error {
                interceptor?.networkFailedToParseObject(
                    urlRequest: request,
                    urlResponse: response,
                    data: data,
                    error: error
                )
                throw ServiceError<ErrorResponse>.requestFailed(error: error)
            }
                throw ServiceError<ErrorResponse>.backendError(error: result)
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
            (data, response, httpResponse) = try await performRequest(
                request: request,
                requestData: nil,
                urlSessionProvider: urlSession,
                interceptor: interceptor
            )
        } catch {
            throw .requestFailed(error: error)
        }

        let decoder = _makeJSONDecoder()

        switch httpResponse.statusCode {
        case 200:
            let result: User
            do {
                result = try decoder.decode(User.self, from: data)
            } catch let error {
                interceptor?.networkFailedToParseObject(
                    urlRequest: request,
                    urlResponse: response,
                    data: data,
                    error: error
                )
                throw ServiceError<Void>.requestFailed(error: error)
            }
                return result
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
            (data, response, httpResponse) = try await performRequest(
                request: request,
                requestData: nil,
                urlSessionProvider: urlSession,
                interceptor: interceptor
            )
        } catch {
            throw .requestFailed(error: error)
        }

        let decoder = _makeJSONDecoder()

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
            let result: ErrorResponse
            do {
                result = try decoder.decode(ErrorResponse.self, from: data)
            } catch let error {
                interceptor?.networkFailedToParseObject(
                    urlRequest: request,
                    urlResponse: response,
                    data: data,
                    error: error
                )
                throw ServiceError<ErrorResponse>.requestFailed(error: error)
            }
                throw ServiceError<ErrorResponse>.backendError(error: result)
        default:
            throw .requestFailed(error: _unknownStatusError(statusCode: httpResponse.statusCode, data: data))
        }
    }
}
