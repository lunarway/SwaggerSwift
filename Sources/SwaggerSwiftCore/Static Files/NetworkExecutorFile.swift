let networkExecutor = """
    import Foundation

    <ACCESSCONTROL> struct NetworkExecutor {
        private let urlSession: () -> URLSession
        private let interceptor: NetworkInterceptor?
        
        init(
            urlSession: @escaping () -> URLSession,
            interceptor: NetworkInterceptor?
        ) {
            self.urlSession = urlSession
            self.interceptor = interceptor
        }
        
        func executeRequest(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
            let data: Data
            let response: URLResponse
            
            do {
                (data, response) = try await urlSession().data(for: request)
            } catch {
                throw ServiceError<Never>.requestFailed(error: error)
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                fatalError("The response must be a URL response")
            }
            
            if let interceptor = interceptor {
                do {
                    try await interceptor.networkDidPerformRequest(
                        urlRequest: request,
                        urlResponse: response,
                        data: data,
                        error: nil
                    )
                } catch {
                    throw ServiceError<Never>.requestFailed(error: error)
                }
            }
            
            return (data, httpResponse)
        }
        
        func executeUploadRequest(_ request: URLRequest, from data: Data) async throws -> (Data, HTTPURLResponse) {
            let responseData: Data
            let response: URLResponse
            
            do {
                (responseData, response) = try await urlSession().upload(for: request, from: data)
            } catch {
                throw ServiceError<Never>.requestFailed(error: error)
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                fatalError("The response must be a URL response")
            }
            
            if let interceptor = interceptor {
                do {
                    try await interceptor.networkDidPerformRequest(
                        urlRequest: request,
                        urlResponse: response,
                        data: responseData,
                        error: nil
                    )
                } catch {
                    throw ServiceError<Never>.requestFailed(error: error)
                }
            }
            
            return (responseData, httpResponse)
        }
    }
    """
