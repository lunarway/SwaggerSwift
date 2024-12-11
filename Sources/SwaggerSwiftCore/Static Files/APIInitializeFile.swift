let apiInitializeFile = """
import Foundation

/// Provides a single common interface for initialising all APIs
public protocol APIInitialize {
    init(urlSession: @escaping () -> URLSession,
         baseUrlProvider: @escaping () -> URL,
         headerProvider: @escaping () async -> any GlobalHeaders,
         interceptor: (any NetworkInterceptor)?
    )
}

"""
