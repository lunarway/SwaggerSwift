let requestRuntime = """
    import Foundation

    // Common runtime helpers used by generated API functions. Emitted once in the Shared target.

    @inlinable public func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom(dateDecodingStrategy)
        return decoder
    }

    @inlinable public func applyHeaders(_ headers: [String: String?], to request: inout URLRequest) {
        for (name, value) in headers {
            if let value { request.setValue(value, forHTTPHeaderField: name) }
        }
    }

    @inlinable public func httpError(domain: String, statusCode: Int, data: Data) -> Error {
        let message = String(data: data, encoding: .utf8) ?? ""
        return NSError(domain: domain, code: statusCode, userInfo: [NSLocalizedDescriptionKey: message])
    }

    @inlinable public func perform<E: Sendable>(
        _ request: URLRequest,
        uploadData: Data? = nil,
        urlSession: @escaping @Sendable () async -> URLSession,
        interceptor: (any NetworkInterceptor)?
    ) async throws(ServiceError<E>) -> (Data, HTTPURLResponse) {
        let req = interceptor?.networkWillPerformRequest(request) ?? request

        let data: Data
        let response: URLResponse
        do {
            if let uploadData {
                (data, response) = try await urlSession().upload(for: req, from: uploadData)
            } else {
                (data, response) = try await urlSession().data(for: req)
            }
        } catch {
            throw .requestFailed(error: error)
        }

        if let interceptor {
            do {
                try await interceptor.networkDidPerformRequest(
                    urlRequest: req,
                    urlResponse: response,
                    data: data,
                    error: nil
                )
            } catch {
                throw .requestFailed(error: error)
            }
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            fatalError("The response must be a URL response")
        }

        return (data, httpResponse)
    }

    @inlinable public func decode<T: Decodable, E: Sendable>(
        _ type: T.Type,
        from data: Data,
        request: URLRequest,
        response: URLResponse,
        interceptor: (any NetworkInterceptor)?,
        errorType: ServiceError<E>.Type
    ) throws(ServiceError<E>) -> T {
        do {
            return try makeDecoder().decode(T.self, from: data)
        } catch {
            interceptor?.networkFailedToParseObject(
                urlRequest: request,
                urlResponse: response,
                data: data,
                error: error
            )
            throw .requestFailed(error: error)
        }
    }

    @inlinable public func decodeScalar<T: LosslessStringConvertible, E: Sendable>(
        _ type: T.Type,
        from data: Data,
        apiName: String,
        errorType: ServiceError<E>.Type
    ) throws(ServiceError<E>) -> T {
        if let stringValue = String(data: data, encoding: .utf8), let value = T(stringValue) {
            return value
        } else {
            let error = NSError(
                domain: apiName,
                code: 0,
                userInfo: [NSLocalizedDescriptionKey: "Failed to convert backend result to expected type"]
            )
            throw .requestFailed(error: error)
        }
    }
    """
