let apiInitializerFile = """
  import Foundation

  public protocol APIInitializer {
      func initializeApi<API: APIInitialize>(path: String) -> API
  }

  """
