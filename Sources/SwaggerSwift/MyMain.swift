import ArgumentParser
import Foundation
import SwaggerSwiftCore

@main
struct SwaggerSwiftParser: AsyncParsableCommand {
    @Option(
        name: .shortAndLong,
        help: "Path to SwaggerFile (default: auto-detect SwaggerFile.yml or SwaggerFile.yaml in current directory)"
    )
    var swaggerFilePath: String?

    @Option(name: .shortAndLong, help: "Set logging to be verbose")
    var verbose: Bool = false

    @Option(name: .shortAndLong, help: "GitHub token (or set GITHUB_TOKEN env var)")
    var githubToken: String?

    @Option(
        name: .shortAndLong,
        help: "List of APIs to generate, e.g. --api-list lunar-way-onboarding-service",
        transform: { (arg: String) in
            arg.split(separator: ",").map(String.init)
        }
    )
    var apiList: [String]?

    mutating func run() async throws {
        guard let token = githubToken ?? ProcessInfo.processInfo.environment["GITHUB_TOKEN"] else {
            throw ValidationError(
                "GitHub token must be provided via --git-hub-token or GITHUB_TOKEN environment variable"
            )
        }

        let apiResponseTypeFactory = APIResponseTypeFactory()
        let objectModelFactory = ObjectModelFactory()
        let modelTypeResolver = ModelTypeResolver(objectModelFactory: objectModelFactory)
        objectModelFactory.modelTypeResolver = modelTypeResolver
        let requestParameterFactory = RequestParameterFactory(modelTypeResolver: modelTypeResolver)
        let apiRequestFactory = APIRequestFactory(
            apiResponseTypeFactory: apiResponseTypeFactory,
            requestParameterFactory: requestParameterFactory,
            modelTypeResolver: modelTypeResolver
        )
        
        let swaggerParser = SwaggerSwiftCore.Generator(
            apiRequestFactory: apiRequestFactory,
            modelTypeResolver: modelTypeResolver
        )

        try await swaggerParser.parse(
            swaggerFilePath: swaggerFilePath,
            githubToken: token,
            verbose: verbose,
            dummyMode: false,
            apiFilterList: apiList
        )
    }
}
