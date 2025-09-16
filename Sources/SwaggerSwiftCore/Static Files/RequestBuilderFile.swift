let requestBuilder = """
    import Foundation

    <ACCESSCONTROL> struct RequestBuilder {
        private let baseUrlProvider: () async -> URL
        private let headerProvider: () async -> GlobalHeaders?
        private let interceptor: NetworkInterceptor?
        
        init(
            baseUrlProvider: @escaping () async -> URL,
            headerProvider: @escaping () async -> GlobalHeaders?,
            interceptor: NetworkInterceptor?
        ) {
            self.baseUrlProvider = baseUrlProvider
            self.headerProvider = headerProvider
            self.interceptor = interceptor
        }
        
        func buildRequest(
            path: String,
            method: String,
            headers: [String: String?] = [:],
            body: Data? = nil,
            contentType: String? = nil
        ) async -> URLRequest {
            let endpointUrl = await baseUrlProvider().appendingPathComponent(path)
            var request = URLRequest(url: endpointUrl)
            request.httpMethod = method.uppercased()
            
            // Apply global headers first
            if let globalHeaders = await headerProvider() {
                globalHeaders.add(to: &request)
            }
            
            // Apply request-specific headers
            for (key, value) in headers {
                if let value = value {
                    request.setValue(value, forHTTPHeaderField: key)
                }
            }
            
            // Set content type if provided
            if let contentType = contentType {
                request.setValue(contentType, forHTTPHeaderField: "Content-Type")
            }
            
            // Set body if provided
            request.httpBody = body
            
            // Apply interceptor
            return interceptor?.networkWillPerformRequest(request) ?? request
        }
    }
    """
