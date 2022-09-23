let networkInterceptor = """
import Foundation

<ACCESSCONTROL> protocol NetworkInterceptor {
    func networkWillPerformRequest(_ request: URLRequest) -> URLRequest
    func networkDidPerformRequest(urlRequest: URLRequest, urlResponse: URLResponse?, data: Data?, error: Error?) async -> Error?
    /// Called when the network fails to parse a response object as based on the Swagger spec. This probably means that the Swagger spec is in-compliant with the actual API.
    /// - Parameters:
    ///   - urlRequest: the URLRequest
    ///   - urlResponse: the URLResponse
    ///   - data: the payload
    ///   - error: the parsing error
    func networkFailedToParseObject(urlRequest: URLRequest, urlResponse: URLResponse?, data: Data?, error: Error?)
}

"""
