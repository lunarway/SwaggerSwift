import ArgumentParser
import SwaggerSwiftCore

@main
struct SwaggerSwiftParser: AsyncParsableCommand {
  @Option(name: .shortAndLong, help: "Path to SwaggerFile")
  var swaggerFilePath: String = "./SwaggerFile"

  @Option(name: .shortAndLong, help: "Set logging to be verbose")
  var verbose: Bool = false

  @Argument(help: "GitHub token")
  var gitHubToken: String

  @Option(
    name: .shortAndLong,
    help: "List of APIs to generate, e.g. --api-list lunar-way-onboarding-service",
    transform: { (arg: String) in
      arg.split(separator: ",").map(String.init)
    })
  var apiList: [String]?

  mutating func run() async throws {
    let apiResponseTypeFactory = APIResponseTypeFactory()
    let objectModelFactory = ObjectModelFactory()
    let modelTypeResolver = ModelTypeResolver(objectModelFactory: objectModelFactory)
    objectModelFactory.modelTypeResolver = modelTypeResolver
    let requestParameterFactory = RequestParameterFactory(modelTypeResolver: modelTypeResolver)
    let apiRequestFactory = APIRequestFactory(
      apiResponseTypeFactory: apiResponseTypeFactory,
      requestParameterFactory: requestParameterFactory,
      modelTypeResolver: modelTypeResolver)
    let swaggerParser = SwaggerSwiftCore.Generator(
      apiRequestFactory: apiRequestFactory, modelTypeResolver: modelTypeResolver)
    try await swaggerParser.parse(
      swaggerFilePath: swaggerFilePath,
      githubToken: gitHubToken,
      verbose: verbose,
      dummyMode: false,
      apiFilterList: apiList
    )
  }
}
