let networkInterceptor = """
    public import Foundation

    public protocol NetworkInterceptor: Sendable {
        func networkWillPerformRequest(
            _ request: URLRequest
        ) -> URLRequest

        /// Called when a request has been made. Use this to intercept any response to perform some other behaviour. If the function throws an error, it will
        /// push the error back to the response callsite.
        /// - Parameters:
        ///   - urlRequest: the original request object
        ///   - urlResponse: the response object
        ///   - data: the data received, if any
        ///   - error: the error, if any
        func networkDidPerformRequest(
            urlRequest: URLRequest,
            urlResponse: URLResponse?,
            data: Data?,
            error: Error?
        ) async throws

        /// Called when the network fails to parse a response object as based on the Swagger spec.
        /// This probably means that the Swagger spec is in-compliant with the actual API.
        /// - Parameters:
        ///   - urlRequest: the URLRequest
        ///   - urlResponse: the URLResponse
        ///   - data: the payload
        ///   - error: the parsing error
        func networkFailedToParseObject(
            urlRequest: URLRequest,
            urlResponse: URLResponse?,
            data: Data?,
            error: Error?
        )
    }

    """
