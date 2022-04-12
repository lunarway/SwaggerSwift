import Foundation
import SwaggerSwiftML

public struct SwaggerParser {
    let apiRequestFactory: APIRequestFactory
    let modelTypeResolver: ModelTypeResolver

    public init(apiRequestFactory: APIRequestFactory, modelTypeResolver: ModelTypeResolver) {
        self.apiRequestFactory = apiRequestFactory
        self.modelTypeResolver = modelTypeResolver
    }

    /// Parse and generate the network layer for a SwaggerFile
    /// - Parameters:
    ///   - swaggerFilePath: The path to the SwaggerFile
    ///   - githubToken: A GitHub token
    ///   - destinationPath: The path to where the API Swift Package should be created
    ///   - projectName: The api suite name
    ///   - verbose: Should logs be shown
    ///   - apiFilterList: A list of APIs that should be parsed - can be used to filter away other APIs
    public func parse(swaggerFilePath: String, githubToken: String, destinationPath: String, projectName: String, verbose: Bool = false, dummyMode: Bool = false, apiFilterList: [String]?) async throws {
        isVerboseMode = verbose

        let fileManager = FileManager.default
        let commonLibraryName = "\(projectName)Shared"
        let swiftPackageSourcesDirectory = destinationPath + "/Sources"

        log("Parsing SwaggerFile at: \(swaggerFilePath)")
        let swaggerFile = try SwaggerFileParser.parse(
            at: swaggerFilePath,
            fileManager: fileManager
        )

        let services: [String: SwaggerFile.Service]
        if let apiFilterList = apiFilterList {
            services = swaggerFile.services.filter { apiFilterList.contains($0.key) }
        } else {
            services = swaggerFile.services
        }

        try fileManager.createDirectory(
            atPath: swiftPackageSourcesDirectory,
            withIntermediateDirectories: true,
            attributes: nil
        )

        let swaggers: [Swagger] = await withTaskGroup(of: Swagger?.self) { group in
            for service in services {
                group.addTask {
                    do {
                        async let swagger = try await downloadSwagger(
                            githubToken: githubToken,
                            organisation: swaggerFile.organisation,
                            serviceName: service.key,
                            branch: service.value.branch ?? "master",
                            swaggerPath: service.value.path ?? swaggerFile.path
                        )

                        try await parse(
                            swagger: swagger,
                            swaggerFile: swaggerFile,
                            swiftPackageSourcesDirectory: swiftPackageSourcesDirectory,
                            commonLibraryName: commonLibraryName,
                            fileManager: fileManager,
                            dummyMode: dummyMode
                        )

                        return try await swagger
                    } catch let error {
                        if let error = error as? FetchSwaggerError {
                            error.logError()
                        } else if let error = error as? APIRequestFactory.APIRequestFactoryError {
                            switch error {
                            case .unsupportedMimeType(let httpMethod, let servicePath, let mimeType):
                                log("[\(service.key) \(httpMethod) \(servicePath)] Swagger is using invalid mime type: \(mimeType)", error: true)
                            case .missingConsumeType(let httpMethod, let servicePath):
                                log("[\(service.key) \(httpMethod) \(servicePath)] Swagger is not specifying the mimetype", error: true)
                            }
                        } else {
                            log("[\(service.key)] Failed to download Swagger: \(error.localizedDescription)", error: true)
                        }

                        return nil
                    }
                }
            }

            var swaggers = [Swagger]()
            for await swagger in group {
                if let swagger = swagger {
                    swaggers.append(swagger)
                }
            }

            return swaggers
        }

        log("Creating Swift Project at \(destinationPath)")

        try createPackageSwiftFile(
            at: destinationPath,
            named: projectName,
            commonLibraryName: commonLibraryName,
            apis: swaggers.map(\.serviceName)
        )

        try createCommonLibrary(
            path: swiftPackageSourcesDirectory,
            commonLibraryName: commonLibraryName,
            swaggerFile: swaggerFile,
            fileManager: fileManager
        )
    }

    private func downloadSwagger(githubToken: String, organisation: String, serviceName: String, branch: String, swaggerPath: String, urlSession: URLSession = .shared) async throws -> Swagger {
        let url = URL(string: "https://raw.githubusercontent.com/\(organisation)/\(serviceName)/\(branch)/\(swaggerPath)")!
        var request = URLRequest(url: url)
        request.addValue("token \(githubToken)", forHTTPHeaderField: "Authorization")
        request.addValue("application/vnd.github.v3.raw", forHTTPHeaderField: "Accept")

        log("Downloading Swagger at: \(url.absoluteString)")
        let (data, response) = try await URLSession.shared.data(for: request)
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            throw FetchSwaggerError.requestFailed(serviceName: serviceName, branch: branch, statusCode: httpResponse.statusCode)
        }

        guard let stringValue = String(data: data, encoding: .utf8) else {
            throw FetchSwaggerError.invalidResponse(serviceName: serviceName)
        }

        do {
            let swagger = try SwaggerReader.read(text: stringValue)
            return swagger
        } catch let error {
            throw FetchSwaggerError.couldNotParse(serviceName: serviceName, error)
        }
    }

    private func parse(swagger: Swagger, swaggerFile: SwaggerFile, swiftPackageSourcesDirectory: String, commonLibraryName: String, fileManager: FileManager, dummyMode: Bool) throws {
        log("Parsing contents of Swagger: \(swagger.serviceName)")

        let apiDirectory = swiftPackageSourcesDirectory + "/" + swagger.serviceName
        let modelDirectory = "\(apiDirectory)/Models"

        if !dummyMode {
            // remove existing files
            var trueValue = ObjCBool(true)
            if fileManager.fileExists(atPath: modelDirectory, isDirectory: &trueValue) {
                try fileManager.removeItem(atPath: apiDirectory)
            }

            // create directories
            try fileManager.createDirectory(atPath: modelDirectory, withIntermediateDirectories: true, attributes: nil)
        }

        let (apiDefinition, apiModelDefinitions) = try APIFactory(apiRequestFactory: apiRequestFactory, modelTypeResolver: modelTypeResolver).generate(for: swagger, withSwaggerFile: swaggerFile)

        let apiDefinitionFile = apiDefinition.toSwift(
            swaggerFile: swaggerFile,
            packagesToImport: [commonLibraryName]
        )

        let apiDefinitionFilename = "\(apiDirectory)/\(apiDefinition.serviceName).swift"
        try apiDefinitionFile.write(
            toFile: apiDefinitionFilename,
            atomically: true,
            encoding: .utf8
        )

        log("[\(swagger.serviceName)] 🖨 \(apiDefinitionFilename)")

        for apiModel in apiModelDefinitions {
            let file = apiModel.toSwift(
                serviceName: swagger.serviceName,
                embedded: false,
                packagesToImport: [commonLibraryName]
            )

            let filename = "\(modelDirectory)/\(apiDefinition.serviceName)_\(apiModel.typeName).swift"
            try file.write(toFile: filename, atomically: true, encoding: .utf8)

            log("[\(swagger.serviceName)] 🖨 \(filename)")
        }
    }

    private func createCommonLibrary(path: String, commonLibraryName: String, swaggerFile: SwaggerFile, fileManager: FileManager) throws {
        let targetPath = path + "/" + commonLibraryName

        try fileManager.createDirectory(atPath: targetPath,
                                        withIntermediateDirectories: true,
                                        attributes: nil)

        try serviceError.write(toFile: "\(targetPath)/ServiceError.swift", atomically: true, encoding: .utf8)
        try urlQueryItemExtension.write(toFile: "\(targetPath)/URLQueryExtension.swift", atomically: true, encoding: .utf8)
        try jsonParsingErrorExtension.write(toFile: "\(targetPath)/ParsingError.swift", atomically: true, encoding: .utf8)
        try networkInterceptor.write(toFile: "\(targetPath)/NetworkInterceptor.swift", atomically: true, encoding: .utf8)
        try additionalPropertyUtil.write(toFile: "\(targetPath)/AdditionalProperty.swift", atomically: true, encoding: .utf8)
        try formData.write(toFile: "\(targetPath)/FormData.swift", atomically: true, encoding: .utf8)
        try dateDecodingStrategy.write(toFile: "\(targetPath)/DateDecodingStrategy.swift", atomically: true, encoding: .utf8)
        try apiInitializeFile.write(toFile: "\(targetPath)/APIInitialize.swift", atomically: true, encoding: .utf8)

        if let globalHeaderFields = swaggerFile.globalHeaders {
            let globalHeadersModel = GlobalHeadersModel(headerFields: globalHeaderFields)
            let globalHeadersFileContents = globalHeadersModel.toSwift(swaggerFile: swaggerFile)
            try globalHeadersFileContents.write(toFile: "\(targetPath)/GlobalHeaders.swift", atomically: true, encoding: .utf8)
        }
    }

    /// Creates the Package.swift file used in the Swift package
    /// - Parameters:
    ///   - path: the path to the swift package
    ///   - name: the swift package name
    ///   - commonLibraryName: The name of the common library. The common library is a library that contains the common SwaggerSwift files shared between the different API targets.
    ///   - targets: the name of the API targets
    ///   - fileManager: the file manager
    /// - Throws: Throws if the files couldnt be created on disk
    private func createPackageSwiftFile(at path: String, named name: String, commonLibraryName: String, apis: [String], fileManager: FileManager = FileManager.default) throws {
        let commonTarget = SwiftPackageBuilder.Target(type: .target, name: commonLibraryName)
        let apiTargets = apis.map {
            SwiftPackageBuilder.Target(
                type: .target,
                name: $0,
                dependencies: [commonTarget]
            )
        }

        var targets = [commonTarget]
        targets.append(contentsOf: apiTargets)

        let product = SwiftPackageBuilder.Product(name: name, targets: targets)
        let packageBuilder = SwiftPackageBuilder(projectName: name, platforms: "", products: [product])

        let packageFile = packageBuilder.buildPackageFile()

        let expandedPath = path.replacingOccurrences(of: "~", with: NSHomeDirectory())
        // create the initial directory
        try fileManager.createDirectory(atPath: expandedPath, withIntermediateDirectories: true)

        // write package swift file
        try packageFile.write(toFile: expandedPath + "/Package.swift", atomically: true, encoding: .utf8)
    }
}
