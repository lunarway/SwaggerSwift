let apiInitializeFile = """
import Foundation

/// Provides a single common interface for initialising all APIs
public protocol APIInitialize {
    init(urlSession: @escaping @Sendable () async -> URLSession,
         baseUrlProvider: @escaping @Sendable () async -> URL,
         headerProvider: @escaping @Sendable () async -> any GlobalHeaders,
         interceptor: (any NetworkInterceptor)?
    )
}

"""
