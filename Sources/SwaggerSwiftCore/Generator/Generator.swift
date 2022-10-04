import Foundation
import SwaggerSwiftML
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public struct Generator {
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
    ///   - createPackage: should the files just be written to a directory, or should a swift package be generated?
    ///   - verbose: Should logs be shown
    ///   - apiFilterList: A list of APIs that should be parsed - can be used to filter away other APIs
    public func parse(swaggerFilePath: String?, githubToken: String, verbose: Bool = false, dummyMode: Bool = false, apiFilterList: [String]?) async throws {
        isVerboseMode = verbose

        let fileManager = FileManager.default

        let swaggerFilePath = swaggerFilePath ?? "./SwaggerFile.yml"

        log("Parsing SwaggerFile at: \(swaggerFilePath)")
        let swaggerFile = try SwaggerFileParser.parse(
            at: swaggerFilePath,
            fileManager: fileManager
        )

        let accessControl = swaggerFile.accessControl

        let services: [String: SwaggerFile.Service]
        if let apiFilterList = apiFilterList {
            services = swaggerFile.services.filter { apiFilterList.contains($0.key) }
        } else {
            services = swaggerFile.services
        }

        typealias APISpec = (APIDefinition, [ModelDefinition])

        let apiSpecs: [APISpec] = await withTaskGroup(of: APISpec?.self) { group in
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

                        let apiSpec = try await APIFactory(apiRequestFactory: apiRequestFactory,
                                                           modelTypeResolver: modelTypeResolver)
                            .generate(for: swagger, withSwaggerFile: swaggerFile)

                        return apiSpec
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

            var apiSpecs = [APISpec]()
            for await spec in group {
                if let spec = spec {
                    apiSpecs.append(spec)
                }
            }

            return apiSpecs
        }

        let destination = URL(fileURLWithPath: swaggerFilePath).deletingLastPathComponent().appendingPathComponent(swaggerFile.destination).path

        log("Creating Swift Project at \(destination)")

        let globalHeadersModel = GlobalHeadersModel(headerFields: swaggerFile.globalHeaders ?? [])
        let commonLibraryName = "\(swaggerFile.projectName)Shared"

        if swaggerFile.createSwiftPackage {
            let projectRoot = "\(destination)/\(swaggerFile.projectName)"
            let swiftPackageSourcesDirectory = "\(projectRoot)/Sources"

            try fileManager.createDirectory(
                atPath: destination,
                withIntermediateDirectories: true,
                attributes: nil
            )

            for spec in apiSpecs {
                try write(apiDefinition: spec.0,
                          modelDefinitions: spec.1,
                          swaggerFile: swaggerFile,
                          rootDirectory: swiftPackageSourcesDirectory,
                          commonLibraryName: commonLibraryName,
                          accessControl: accessControl,
                          globalHeadersModel: globalHeadersModel,
                          fileManager: fileManager,
                          dummyMode: dummyMode)
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
                accessControl: .public, // this needs to be public for the other files to see it
                fileManager: fileManager
            )
        } else {
            let rootDir = "\(destination)/\(swaggerFile.projectName)"

            try fileManager.createDirectory(
                atPath: rootDir,
                withIntermediateDirectories: true,
                attributes: nil
            )

            for spec in apiSpecs {
                try write(apiDefinition: spec.0,
                          modelDefinitions: spec.1,
                          swaggerFile: swaggerFile,
                          rootDirectory: rootDir,
                          commonLibraryName: nil,
                          accessControl: accessControl,
                          globalHeadersModel: globalHeadersModel,
                          fileManager: fileManager,
                          dummyMode: dummyMode)
            }

            try createCommonLibrary(
                path: rootDir,
                commonLibraryName: commonLibraryName,
                swaggerFile: swaggerFile,
                accessControl: accessControl,
                fileManager: fileManager
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

    private func downloadSwagger(githubToken: String, organisation: String, serviceName: String, branch: String, swaggerPath: String, urlSession: URLSession = .shared) async throws -> Swagger {
        let url = URL(string: "https://raw.githubusercontent.com/\(organisation)/\(serviceName)/\(branch)/\(swaggerPath)")!
        var request = URLRequest(url: url)
        request.addValue("token \(githubToken)", forHTTPHeaderField: "Authorization")
        request.addValue("application/vnd.github.v3.raw", forHTTPHeaderField: "Accept")

        log("Downloading Swagger at: \(url.absoluteString)")
        let (data, response) = try await fetchSwagger(request)
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

    private func write(apiDefinition: APIDefinition, modelDefinitions: [ModelDefinition], swaggerFile: SwaggerFile, rootDirectory: String, commonLibraryName: String?, accessControl: APIAccessControl, globalHeadersModel: GlobalHeadersModel, fileManager: FileManager, dummyMode: Bool) throws {
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
            try fileManager.createDirectory(atPath: modelDirectory, withIntermediateDirectories: true, attributes: nil)
        }

        let apiDefinitionFile = apiDefinition.toSwift(
            swaggerFile: swaggerFile,
            accessControl: accessControl.rawValue,
            packagesToImport: commonLibraryName != nil ? [commonLibraryName!] : []
        )

        let globalHeadersDefinitions = globalHeadersModel.writeExtensions(inCommonPackageNamed: commonLibraryName)
        let globalHeaderExtensionsPath = "\(apiDirectory)/GlobalHeaderExtensions.swift"
        try globalHeadersDefinitions.write(toFile: globalHeaderExtensionsPath)

        let apiDefinitionFilename = "\(apiDirectory)/\(apiDefinition.serviceName).swift"
        try apiDefinitionFile.write(toFile: apiDefinitionFilename)

        log("[\(apiDefinition.serviceName)] 🖨 \(apiDefinitionFilename)")

        for apiModel in modelDefinitions {
            let file = apiModel.toSwift(
                serviceName: apiDefinition.serviceName,
                embedded: false,
                accessControl: swaggerFile.accessControl,
                packagesToImport: commonLibraryName != nil ? [commonLibraryName!] : []
            )

            let filename = "\(modelDirectory)/\(apiDefinition.serviceName)_\(apiModel.typeName).swift"
            try file.write(toFile: filename)

            log("[\(apiDefinition.serviceName)] 🖨 \(filename)")
        }
    }

    private func createCommonLibrary(path: String, commonLibraryName: String, swaggerFile: SwaggerFile, accessControl: APIAccessControl, fileManager: FileManager) throws {
        let targetPath = path + "/" + commonLibraryName

        try fileManager.createDirectory(atPath: targetPath,
                                        withIntermediateDirectories: true,
                                        attributes: nil)

        let accControl: String = accessControl.rawValue

        try serviceError.replacingOccurrences(of: "<ACCESSCONTROL>", with: accControl).write(toFile: "\(targetPath)/ServiceError.swift")
        try urlQueryItemExtension.replacingOccurrences(of: "<ACCESSCONTROL>", with: accControl).write(toFile: "\(targetPath)/URLQueryExtension.swift")
        try jsonParsingErrorExtension.replacingOccurrences(of: "<ACCESSCONTROL>", with: accControl).write(toFile: "\(targetPath)/ParsingError.swift")
        try networkInterceptor.replacingOccurrences(of: "<ACCESSCONTROL>", with: accControl).write(toFile: "\(targetPath)/NetworkInterceptor.swift")
        try additionalPropertyUtil.replacingOccurrences(of: "<ACCESSCONTROL>", with: accControl).write(toFile: "\(targetPath)/AdditionalProperty.swift")
        try formData.replacingOccurrences(of: "<ACCESSCONTROL>", with: accControl).write(toFile: "\(targetPath)/FormData.swift")
        try dateDecodingStrategy.replacingOccurrences(of: "<ACCESSCONTROL>", with: accControl).write(toFile: "\(targetPath)/DateDecodingStrategy.swift")
        try apiInitializeFile.replacingOccurrences(of: "<ACCESSCONTROL>", with: accControl).write(toFile: "\(targetPath)/APIInitialize.swift")
        try apiInitializerFile.replacingOccurrences(of: "<ACCESSCONTROL>", with: accControl).write(toFile: "\(targetPath)/APIInitializer.swift")

        if let globalHeaderFields = swaggerFile.globalHeaders {
            let globalHeadersModel = GlobalHeadersModel(headerFields: globalHeaderFields)
            let globalHeadersFileContents = globalHeadersModel.toSwift(swaggerFile: swaggerFile, accessControl: accessControl)
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
        try packageFile.write(toFile: expandedPath + "/Package.swift", addHeader: false)
    }
}

extension String {
    func write(toFile path: String, addHeader: Bool = true) throws {
        if addHeader {
            let file = "// Autogenerated with ❤️ by SwaggerSwift\n// Do not modify this file manually 🙅\n\n" + self
            try file.write(toFile: path, atomically: true, encoding: .utf8)
        } else {
            try self.write(toFile: path, atomically: true, encoding: .utf8)
        }
    }
}
