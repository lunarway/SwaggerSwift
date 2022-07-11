let apiInitializeFile = """
import Foundation

<ACCESSCONTROL> protocol APIInitialize {
    init(urlSession: @escaping () -> URLSession,
         baseUrlProvider: @escaping () -> URL,
         headerProvider: @escaping () -> GlobalHeaders,
         interceptor: NetworkInterceptor?
    )
}
"""
