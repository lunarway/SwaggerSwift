import Foundation
import SwaggerSwiftML

enum HTTPMethod: String {
    case get, put, post, delete, patch, options, head
}

let serviceError = """
enum ServiceError<ErrorType>: Error {
    // An error occured that is caused by the client app, and not the request
    case clientError(reason: String)
    // The request failed, e.g. timeout
    case requestFailed(error: Error)
    // The backend returned an error, e.g. a 500 Internal Server Error, 403 Unauthorized
    case backendError(error: ErrorType)
}
"""
let path = "/Users/madsbogeskov/Developer/SwaggerFile.yml"
let swaggers = try SwaggerFileParser.parse(path: path, authToken: "d9545c1fa435fccacbb5e6fd2339e38c6b3e7936")

let sourceDirectory = try! createSwiftProject(at: "~/TestProject", named: "Services")

let modelDirectory = "\(sourceDirectory)/Models"
try! serviceError.write(toFile: "\(sourceDirectory)/ServiceError.swift", atomically: true, encoding: .utf8)

for swagger in swaggers {
    let serviceDirectory = "\(sourceDirectory)/\(swagger.serviceName)"
    let modelDirectory = "\(serviceDirectory)/Models"
    try! FileManager.default.createDirectory(atPath: serviceDirectory, withIntermediateDirectories: true, attributes: nil)
    try! FileManager.default.createDirectory(atPath: modelDirectory, withIntermediateDirectories: true, attributes: nil)

    let serviceDefinition = parse(swagger: swagger)

    try! serviceDefinition.toSwift()
        .write(toFile: "\(serviceDirectory)/\(serviceDefinition.typeName).swift", atomically: true, encoding: .utf8)

    for type in serviceDefinition.innerTypes {
        let file = type.toSwift()
        let prefix = swagger.serviceName.filter { !$0.unicodeScalars.map(CharacterSet.uppercaseLetters.contains).contains(false) }
        let filename = "\(modelDirectory)/\(prefix)\(type.typeName).swift"
        try! file.write(toFile: filename, atomically: true, encoding: .utf8)
        print("Wrote \(filename)")
    }
}
