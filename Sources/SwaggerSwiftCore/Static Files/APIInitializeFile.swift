let apiInitializeFile = """
import Foundation

public protocol APIInitialize {
    init(urlSession: @escaping () -> URLSession,
         baseUrlProvider: @escaping () -> URL,
         headerProvider: @escaping () -> GlobalHeaders,
         interceptor: NetworkInterceptor?
    )
}
"""
