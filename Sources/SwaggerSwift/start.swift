import Foundation
import SwaggerSwiftML
import os
import os.log

enum HTTPMethod: String {
    case get, put, post, delete, patch, options, head
}

// token
func start(swaggerFilePath: String, token: String, destinationPath: String, projectName: String = "Services", verbose: Bool = false) throws {
    if verbose {
        print("Parsing swagger at \(swaggerFilePath)")
    }

    let (swaggers, swaggerFile) = try SwaggerFileParser.parse(path: swaggerFilePath, authToken: token, verbose: verbose)

    if verbose {
        print("Creating Swift Project at \(destinationPath) named \(projectName)")
    }

    let (sourceDirectory, testDirectory) = try! createSwiftProject(at: destinationPath, named: projectName)

    if let templateDirectory = Bundle.module.resourceURL?.appendingPathComponent("Templates") {
        for file in try FileManager.default.contentsOfDirectory(at: templateDirectory, includingPropertiesForKeys: nil, options: []) {
            let cwd = URL(string: FileManager.default.currentDirectoryPath)!
            let destination: URL
            if file.absoluteString.contains("Test") {
                destination = URL(fileURLWithPath: "\(testDirectory)/\(file.lastPathComponent)", relativeTo: cwd)
            } else {
                destination = URL(fileURLWithPath: "\(sourceDirectory)/\(file.lastPathComponent)", relativeTo: cwd)
            }

            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }

            try FileManager.default.copyItem(at: file, to: destination)
        }
    }

    if let globalHeaderFields = swaggerFile.globalHeaders?.map({
        ModelField(description: nil,
                   type: .string,
                   name: makeHeaderFieldName(headerName: $0),
                   required: true)
    }) {
        let globalHeaders = Model(description: nil,
                                  typeName: "GlobalHeaders",
                                  fields: globalHeaderFields,
                                  inheritsFrom: [],
                                  isInternalOnly: false,
                                  embeddedDefinitions: [])

        try! globalHeaders.toSwift(serviceName: nil,
                                   swaggerFile: swaggerFile,
                                   embedded: false)
            .write(toFile: "\(sourceDirectory)/GlobalHeaders.swift", atomically: true, encoding: .utf8)
    }

    for swagger in swaggers {
        if verbose {
            print("Parsing contents of Swagger: \(swagger.serviceName)")
        }

        let serviceDirectory = "\(sourceDirectory)/\(swagger.serviceName)"
        let modelDirectory = "\(serviceDirectory)/Models"
        try! FileManager.default.createDirectory(atPath: serviceDirectory, withIntermediateDirectories: true, attributes: nil)
        try! FileManager.default.createDirectory(atPath: modelDirectory, withIntermediateDirectories: true, attributes: nil)

        let filePrefix = "\(swagger.serviceName.filter { !$0.unicodeScalars.map(CharacterSet.uppercaseLetters.contains).contains(false) })_"

        let serviceDefinition = parse(swagger: swagger, swaggerFile: swaggerFile)

        try! serviceDefinition.toSwift(serviceName: swagger.serviceName, swaggerFile: swaggerFile, embedded: false)
            .write(toFile: "\(serviceDirectory)/\(serviceDefinition.typeName).swift", atomically: true, encoding: .utf8)

        for type in serviceDefinition.innerTypes {
            let file = type.toSwift(serviceName: swagger.serviceName, swaggerFile: swaggerFile, embedded: false)
            let filename = "\(modelDirectory)/\(filePrefix)\(type.typeName).swift"
            try! file.write(toFile: filename, atomically: true, encoding: .utf8)
            if verbose {
                print("Wrote \(filename)")
            }
        }
    }
}
