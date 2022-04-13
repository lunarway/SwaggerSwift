let apiInitializeFile = """
import Foundation

public protocol APIInitialize {
    init(urlSession: @escaping () -> URLSession,
         baseUrl: @escaping () -> URL,
         headerProvider: @escaping () -> GlobalHeaders,
         interceptor: NetworkInterceptor?
    )
}
"""
