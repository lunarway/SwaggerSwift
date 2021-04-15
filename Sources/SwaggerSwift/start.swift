import Foundation
import SwaggerSwiftML
import os
import os.log

enum HTTPMethod: String {
    case get, put, post, delete, patch, options, head
}

let serviceError = """
public enum ServiceError<ErrorType>: Error {
    // An error occured that is caused by the client app, and not the request
    case clientError(reason: String)
    // The request failed, e.g. timeout
    case requestFailed(error: Error)
    // The backend returned an error, e.g. a 500 Internal Server Error, 403 Unauthorized
    case backendError(error: ErrorType)
}
"""

let urlQueryItemExtension = """
import Foundation

extension URLQueryItem {
    init(name: String, value: Bool) {
        self.init(name: name, value: value ? "true" : "false")
    }
}
"""

let parsingErrorExtension = """
import Foundation

public enum JSONParsingError: Error {
    case invalidDate(String)
}
"""

let networkInterceptor = """
import Foundation

public enum NetworkResult {
    case failed(Error)
    case success(HTTPURLResponse, Data)
}

public protocol NetworkInterceptor {
    func networkWillPerformRequest(_ request: URLRequest) -> URLRequest
    func networkDidPerformRequest(_ result: NetworkResult)
}
"""

let dummyTest = """
import XCTest

public struct DummyTest {
    func testNetwork() {
        XCTAssertTrue(true)
    }
}
"""
// token
func start(swaggerFilePath: String, token: String, destinationPath: String, projectName: String = "Services", verbose: Bool = false) throws {
    let swaggers = try SwaggerFileParser.parse(path: swaggerFilePath, authToken: token)

    let (sourceDirectory, testDirectory) = try! createSwiftProject(at: destinationPath, named: projectName)

    try! serviceError.write(toFile: "\(sourceDirectory)/ServiceError.swift", atomically: true, encoding: .utf8)
    try! urlQueryItemExtension.write(toFile: "\(sourceDirectory)/URLQueryExtension.swift", atomically: true, encoding: .utf8)
    try! parsingErrorExtension.write(toFile: "\(sourceDirectory)/ParsingError.swift", atomically: true, encoding: .utf8)
    try! networkInterceptor.write(toFile: "\(sourceDirectory)/NetworkInterceptor.swift", atomically: true, encoding: .utf8)
    try! dummyTest.write(toFile: "\(testDirectory)/DummyTest.swift", atomically: true, encoding: .utf8)

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
            let filename = "\(modelDirectory)/\(prefix)_\(type.typeName).swift"
            try! file.write(toFile: filename, atomically: true, encoding: .utf8)
            if verbose {
//                os_log("Wrote %s", log: .default, type: .info, filename)
                print("Wrote \(filename)")
            }
        }
    }

}
