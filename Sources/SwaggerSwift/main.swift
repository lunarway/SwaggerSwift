import ArgumentParser
import SwaggerSwiftCore

struct SwaggerSwiftParser: ParsableCommand {
    @Option(name: .shortAndLong, help: "Path to SwaggerFile")
    var swaggerFilePath: String = "./SwaggerFile"

    @Option(name: .shortAndLong, help: "Path where the generated swift package should be placed")
    var destinationPath: String = "./Services"

    @Option(name: .shortAndLong, help: "The name of the generated project")
    var projectName: String = "Services"

    @Option(name: .shortAndLong, help: "Set logging to be verbose")
    var verbose: Bool = false

    @Argument(help: "GitHub token")
    var gitHubToken: String

    @Option(name: .shortAndLong, help: "List of APIs to generate, e.g. --api-list lunar-way-onboarding-service", transform: { (arg: String) in
        arg.split(separator: ",").map(String.init)
    })
    var apiList: [String]?

    mutating func run() throws {
        try start(swaggerFilePath: swaggerFilePath,
                  token: gitHubToken,
                  destinationPath: destinationPath,
                  projectName: projectName,
                  verbose: verbose,
                  apiList: apiList)
    }
}

SwaggerSwiftParser.main()
