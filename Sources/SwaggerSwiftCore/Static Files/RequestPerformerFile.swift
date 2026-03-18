let requestPerformer = """
import Foundation

@Sendable package func performRequest(
    request: URLRequest,
    requestData: Data?,
    urlSessionProvider: @escaping @Sendable () async -> URLSession,
    interceptor: (any NetworkInterceptor)?
) async throws -> (URLRequest, Data, URLResponse, HTTPURLResponse) {
    let request = interceptor?.networkWillPerformRequest(request) ?? request

    let data: Data
    let response: URLResponse
    if let requestData {
        (data, response) = try await urlSessionProvider().upload(for: request, from: requestData)
    } else {
        (data, response) = try await urlSessionProvider().data(for: request)
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

    return (request, data, response, httpResponse)
}
"""
