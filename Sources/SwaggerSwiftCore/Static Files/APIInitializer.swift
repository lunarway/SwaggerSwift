let apiInitializerFile = """
    import Foundation

    public protocol APIInitializer: Sendable {
        func initializeApi<API: APIInitialize>(path: String) -> API
    }

    """
