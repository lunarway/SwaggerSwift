import Foundation

public protocol NetworkInterceptor {
    func networkWillPerformRequest(_ request: URLRequest) -> URLRequest
    func networkDidPerformRequest(urlRequest: URLRequest, urlResponse: URLResponse?, data: Data?, error: Error?) -> Bool
}
