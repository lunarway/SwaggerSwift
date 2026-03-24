import Foundation
import SwaggerSwiftML

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public struct Generator {
    let apiRequestFactory: APIRequestFactory
    let modelTypeResolver: ModelTypeResolver
    let templateRenderer: TemplateRenderer

    public init(apiRequestFactory: APIRequestFactory, modelTypeResolver: ModelTypeResolver) {
        self.apiRequestFactory = apiRequestFactory
        self.modelTypeResolver = modelTypeResolver
        self.templateRenderer = TemplateRenderer()
    }

    private static let swaggerFileCandidates = [
        "SwaggerFile.yml",
        "SwaggerFile.yaml",
    ]

    /// Find a SwaggerFile in the current directory by checking known filenames.
    private static func findSwaggerFile(directory: String?) -> String? {
        guard let directory else { return nil }

        FileManager.default.changeCurrentDirectoryPath(directory)

        for candidate in swaggerFileCandidates {
            let path = "\(directory)/\(candidate)"

            log("looking for SwaggerFile at: \(path)", error: false)

            if FileManager.default.fileExists(atPath: path) {
                return path
            } else {
                log("Did not find SwaggerFile at \(path)", error: false)
            }
        }

        log("Failed to find SwaggerFile", error: true)
        return nil
    }

    /// Parse and generate the network layer for a SwaggerFile
    /// - Parameters:
    ///   - swaggerFilePath: The path to the SwaggerFile
    ///   - githubToken: A GitHub token
    ///   - destinationPath: The path to where the API Swift Package should be created
    ///   - projectName: The api suite name
    ///   - createPackage: should the files just be written to a directory, or should a swift package be generated?
    ///   - verbose: Should logs be shown
    ///   - apiFilterList: A list of APIs that should be parsed - can be used to filter away other APIs
    public func parse(
        swaggerFilePath: String?,
        githubToken: String,
        verbose: Bool = false,
        dummyMode: Bool = false,
        apiFilterList: [String]?
    ) async throws {
        isVerboseMode = verbose

        guard let swaggerFilePath = Self.findSwaggerFile(directory: swaggerFilePath) else {
            throw SwaggerError.fileNotFound
        }

        log("Parsing SwaggerFile at: \(swaggerFilePath)")
        let swaggerFile = try SwaggerFileParser.parse(
            at: swaggerFilePath
        )

        let accessControl = swaggerFile.accessControl

        let services: [String: SwaggerFile.Service]
        if let apiFilterList = apiFilterList {
            services = swaggerFile.services.filter { apiFilterList.contains($0.key) }
        } else {
            services = swaggerFile.services
        }

        typealias APISpec = (APIDefinition, [ModelDefinition])

        var apiSpecs = [APISpec]()

        let apiFactory = APIFactory(
            apiRequestFactory: apiRequestFactory,
            modelTypeResolver: modelTypeResolver
        )

        for (name, service) in services {
            log("Fetching service: \(name)")
            let swagger: Swagger

            do {
                let swaggerPath = service.path ?? swaggerFile.path

                // Check if the swagger path is a local file relative to the SwaggerFile
                let swaggerFileDir = URL(fileURLWithPath: swaggerFilePath).deletingLastPathComponent()
                let localPath = swaggerFileDir.appendingPathComponent(swaggerPath).path
                if FileManager.default.fileExists(atPath: localPath) {
                    log("Reading local Swagger file at: \(localPath)")
                    let contents = try String(contentsOfFile: localPath, encoding: .utf8)
                    swagger = try SwaggerReader.read(text: contents)
                } else {
                    swagger = try await downloadSwagger(
                        githubToken: githubToken,
                        organisation: swaggerFile.organisation,
                        serviceName: name,
                        branch: service.branch ?? "master",
                        swaggerPath: swaggerPath
                    )
                }
            } catch {
                if let error = error as? FetchSwaggerError {
                    error.logError()
                } else if let error = error as? APIRequestFactory.APIRequestFactoryError {
                    switch error {
                    case .unsupportedMimeType(let serviceName, let httpMethod, let servicePath, let mimeType):
                        log(
                            "[\(serviceName) \(httpMethod) \(servicePath)] Swagger is using invalid mime type: \(mimeType)",
                            error: true
                        )
                    case .missingConsumeType(let serviceName, let httpMethod, let servicePath):
                        log(
                            "[\(serviceName) \(httpMethod) \(servicePath)] Swagger is not specifying the mimetype",
                            error: true
                        )
                    }
                } else {
                    log("Failed to download Swagger: \(error.localizedDescription)", error: true)
                }

                return
            }

            do {
                let apiSpec = try apiFactory.generate(
                    for: swagger,
                    withSwaggerFile: swaggerFile
                )

                apiSpecs.append(apiSpec)
            } catch {
                log("Invalid Swagger for service: \(name). Error: \(error.localizedDescription)", error: true)
                return
            }
        }

        let destination = URL(fileURLWithPath: swaggerFilePath).deletingLastPathComponent()
            .appendingPathComponent(swaggerFile.destination).path

        log("Creating Swift Project at \(destination)")

        let globalHeadersModel = GlobalHeadersModel(headerFields: swaggerFile.globalHeaders)
        let commonLibraryName = "\(swaggerFile.projectName)Shared"

        if swaggerFile.createSwiftPackage {
            let projectRoot = "\(destination)/\(swaggerFile.projectName)"
            let swiftPackageSourcesDirectory = "\(projectRoot)/Sources"

            try FileManager.default.createDirectory(
                atPath: destination,
                withIntermediateDirectories: true,
                attributes: nil
            )

            for spec in apiSpecs {
                try write(
                    apiDefinition: spec.0,
                    modelDefinitions: spec.1,
                    swaggerFile: swaggerFile,
                    rootDirectory: swiftPackageSourcesDirectory,
                    commonLibraryName: commonLibraryName,
                    accessControl: accessControl,
                    globalHeadersModel: globalHeadersModel,
                    fileManager: FileManager.default,
                    dummyMode: dummyMode
                )
            }

            try createPackageSwiftFile(
                at: projectRoot,
                named: swaggerFile.projectName,
                commonLibraryName: commonLibraryName,
                apis: apiSpecs.map { $0.0 }.map(\.serviceName).sorted()
            )

            try createCommonLibrary(
                path: swiftPackageSourcesDirectory,
                commonLibraryName: commonLibraryName,
                swaggerFile: swaggerFile,
                accessControl: .public,  // this needs to be public for the other files to see it
                globalHeadersModel: globalHeadersModel,
                fileManager: FileManager.default
            )
        } else {
            let rootDir = "\(destination)/\(swaggerFile.projectName)"

            try FileManager.default.createDirectory(
                atPath: rootDir,
                withIntermediateDirectories: true,
                attributes: nil
            )

            for spec in apiSpecs {
                try write(
                    apiDefinition: spec.0,
                    modelDefinitions: spec.1,
                    swaggerFile: swaggerFile,
                    rootDirectory: rootDir,
                    commonLibraryName: nil,
                    accessControl: accessControl,
                    globalHeadersModel: globalHeadersModel,
                    fileManager: FileManager.default,
                    dummyMode: dummyMode
                )
            }

            try createCommonLibrary(
                path: rootDir,
                commonLibraryName: commonLibraryName,
                swaggerFile: swaggerFile,
                accessControl: accessControl,
                globalHeadersModel: globalHeadersModel,
                fileManager: FileManager.default
            )
        }
    }

    private func fetchSwagger(_ request: URLRequest) async throws -> (Data, URLResponse) {
        enum FetchError: Error {
            case noData
        }
        return try await withCheckedThrowingContinuation { continuation in
            URLSession.shared.dataTask(with: request) { data, response, _ in
                guard let data = data, let response = response else {
                    continuation.resume(throwing: FetchError.noData)
                    return
                }
                continuation.resume(returning: (data, response))
            }.resume()
        }
    }

    private func download(
        githubToken: String,
        organisation: String,
        serviceName: String,
        branch: String,
        swaggerPath: String,
        urlSession: URLSession
    ) async throws -> Data {
        guard
            let url = URL(
                string:
                    "https://raw.githubusercontent.com/\(organisation)/\(serviceName)/\(branch)/\(swaggerPath)"
            )
        else {
            throw FetchSwaggerError.requestFailed(
                serviceName: serviceName,
                branch: branch,
                statusCode: 0
            )
        }
        var request = URLRequest(url: url)
        request.setValue("token \(githubToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github.v3.raw", forHTTPHeaderField: "Accept")

        log("Downloading Swagger at: \(url.absoluteString)")
        let (data, response) = try await fetchSwagger(request)
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            if branch != "master" && branch != "main" {
                log(
                    " ⚠️ \(serviceName): Failed to download with custom branch ´\(branch)´ - Trying master instead.",
                    error: true
                )
                return try await download(
                    githubToken: githubToken,
                    organisation: organisation,
                    serviceName: serviceName,
                    branch: "master",
                    swaggerPath: swaggerPath,
                    urlSession: urlSession
                )
            } else {
                throw FetchSwaggerError.requestFailed(
                    serviceName: serviceName,
                    branch: branch,
                    statusCode: httpResponse.statusCode
                )
            }
        }

        return data
    }

    private func downloadSwagger(
        githubToken: String,
        organisation: String,
        serviceName: String,
        branch: String,
        swaggerPath: String,
        urlSession: URLSession = .shared
    ) async throws -> Swagger {
        let data = try await download(
            githubToken: githubToken,
            organisation: organisation,
            serviceName: serviceName,
            branch: branch,
            swaggerPath: swaggerPath,
            urlSession: urlSession
        )

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

    private func write(
        apiDefinition: APIDefinition,
        modelDefinitions: [ModelDefinition],
        swaggerFile: SwaggerFile,
        rootDirectory: String,
        commonLibraryName: String?,
        accessControl: APIAccessControl,
        globalHeadersModel: GlobalHeadersModel,
        fileManager: FileManager,
        dummyMode: Bool
    ) throws {
        log("Parsing contents of Swagger: \(apiDefinition.serviceName)")

        let apiDirectory = rootDirectory + "/" + apiDefinition.serviceName
        let modelDirectory = "\(apiDirectory)/Models"

        if !dummyMode {
            // remove existing files
            var trueValue = ObjCBool(true)
            if fileManager.fileExists(atPath: modelDirectory, isDirectory: &trueValue) {
                try fileManager.removeItem(atPath: apiDirectory)
            }

            // create directories
            try fileManager.createDirectory(
                atPath: modelDirectory,
                withIntermediateDirectories: true,
                attributes: nil
            )
        }

        let apiDefinitionFile = try apiDefinition.toSwift(
            swaggerFile: swaggerFile,
            accessControl: accessControl.rawValue,
            packagesToImport: commonLibraryName != nil ? [commonLibraryName!] : [],
            templateRenderer: templateRenderer
        )

        if swaggerFile.createSwiftPackage {
            let globalHeadersDefinitions = try globalHeadersModel.writeExtensions(
                inCommonPackageNamed: commonLibraryName,
                templateRenderer: templateRenderer
            )
            let globalHeaderExtensionsPath = "\(apiDirectory)/GlobalHeaderExtensions.swift"
            try globalHeadersDefinitions.write(toFile: globalHeaderExtensionsPath)
        }

        let apiDefinitionFilename = "\(apiDirectory)/\(apiDefinition.serviceName).swift"
        try apiDefinitionFile.write(toFile: apiDefinitionFilename)

        log("[\(apiDefinition.serviceName)] 🖨 \(apiDefinitionFilename)")

        for apiModel in modelDefinitions {
            let file = try apiModel.toSwift(
                serviceName: apiDefinition.serviceName,
                embedded: false,
                accessControl: swaggerFile.accessControl,
                packagesToImport: commonLibraryName != nil ? [commonLibraryName!] : [],
                templateRenderer: templateRenderer
            )

            let filename = "\(modelDirectory)/\(apiDefinition.serviceName)_\(apiModel.typeName).swift"
            try file.write(toFile: filename)

            log("[\(apiDefinition.serviceName)] 🖨 \(filename)")
        }
    }

    private func createCommonLibrary(
        path: String,
        commonLibraryName: String,
        swaggerFile: SwaggerFile,
        accessControl: APIAccessControl,
        globalHeadersModel: GlobalHeadersModel,
        fileManager: FileManager
    ) throws {
        let targetPath = path + "/" + commonLibraryName

        try fileManager.createDirectory(
            atPath: targetPath,
            withIntermediateDirectories: true,
            attributes: nil
        )

        let context: [String: Any] = ["accessControl": accessControl.rawValue]

        let staticFiles: [(template: String, output: String)] = [
            ("ServiceError.stencil", "ServiceError.swift"),
            ("URLQueryExtension.stencil", "URLQueryExtension.swift"),
            ("JsonParsingError.stencil", "ParsingError.swift"),
            ("NetworkInterceptor.stencil", "NetworkInterceptor.swift"),
            ("AdditionalProperty.stencil", "AdditionalProperty.swift"),
            ("FormData.stencil", "FormData.swift"),
            ("DateDecodingStrategy.stencil", "DateDecodingStrategy.swift"),
            ("APIInitialize.stencil", "APIInitialize.swift"),
            ("APIInitializer.stencil", "APIInitializer.swift"),
            ("StringCodingKey.stencil", "StringCodingKey.swift"),
        ]

        for file in staticFiles {
            try templateRenderer.render(template: file.template, context: context)
                .write(toFile: "\(targetPath)/\(file.output)")
        }

        try requestPerformer.write(
            toFile: "\(targetPath)/RequestPerformer.swift"
        )

        if swaggerFile.createSwiftPackage == false {
            let globalHeadersDefinitions = try globalHeadersModel.writeExtensions(
                inCommonPackageNamed: nil,
                templateRenderer: templateRenderer
            )
            let globalHeaderExtensionsPath = "\(targetPath)/GlobalHeaderExtensions.swift"
            try globalHeadersDefinitions.write(toFile: globalHeaderExtensionsPath)
        }

        if swaggerFile.globalHeaders.count > 0 {
            let globalHeadersModel = GlobalHeadersModel(headerFields: swaggerFile.globalHeaders)
            let globalHeadersFileContents = try globalHeadersModel.toSwift(
                templateRenderer: templateRenderer
            )
            try globalHeadersFileContents.write(toFile: "\(targetPath)/GlobalHeaders.swift")
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
    private func createPackageSwiftFile(
        at path: String,
        named name: String,
        commonLibraryName: String,
        apis: [String],
        fileManager: FileManager = FileManager.default
    ) throws {
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

        let expandedPath = NSString(string: path).expandingTildeInPath
        // create the initial directory
        try fileManager.createDirectory(atPath: expandedPath, withIntermediateDirectories: true)

        // write package swift file
        try packageFile.write(toFile: expandedPath + "/Package.swift", addHeader: false)
    }
}

extension String {
    func write(toFile path: String, addHeader: Bool = true) throws {
        if addHeader {
            let file =
                "// Autogenerated with ❤️ by SwaggerSwift\n// Do not modify this file manually 🙅\n\n"
                + self.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) + "\n"
            try file.write(toFile: path, atomically: true, encoding: .utf8)
        } else {
            try self.write(toFile: path, atomically: true, encoding: .utf8)
        }
    }
}
