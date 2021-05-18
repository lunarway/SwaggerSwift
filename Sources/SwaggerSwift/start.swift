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

    init(name: String, value: Int) {
        self.init(name: name, value: String(value))
    }

    init(name: String, value: Int64) {
        self.init(name: name, value: String(value))
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
    case success(URLRequest, HTTPURLResponse, Data)
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

let formData = """
import Foundation

public struct FormData {
    /// the data representation of the object
    public let data: Data
    /// the mime type for the data, e.g. `image/png`
    public let mimeType: String
    /// a filename representing the input - e.g. `image.png`
    public let filename: String

    /// Creates the data part of a multi part request
    /// - Parameters:
    ///   - data: the piece of data being sent
    ///   - mimeType: the mime type for the data, e.g. `image/png`
    ///   - fileName: a filename representing the input - e.g. `image.png`
    public init(data: Data, mimeType: String, fileName: String) {
        self.data = data
        self.mimeType = mimeType
        self.filename = fileName
    }

    internal func toRequestData(named fieldName: String, using boundary: String) -> Data {
        func append(string: String, toData data: NSMutableData) {
            guard let strData = string.data(using: .utf8) else { return }
            data.append(strData)
        }

        let mutableData = NSMutableData()

        append(string: "--\\(boundary)\\r\\n", toData: mutableData)
        append(string: "Content-Disposition: form-data; name=\\"\\(fieldName)\\"; filename=\\"\\(filename)\\"\\r\\n", toData: mutableData)
        append(string: "Content-Type: \\(mimeType)\\r\\n\\r\\n", toData: mutableData)
        mutableData.append(data)
        append(string: "\\r\\n", toData: mutableData)

        return mutableData as Data
    }
}
"""

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

    try! serviceError.write(toFile: "\(sourceDirectory)/ServiceError.swift", atomically: true, encoding: .utf8)
    try! urlQueryItemExtension.write(toFile: "\(sourceDirectory)/URLQueryExtension.swift", atomically: true, encoding: .utf8)
    try! parsingErrorExtension.write(toFile: "\(sourceDirectory)/ParsingError.swift", atomically: true, encoding: .utf8)
    try! networkInterceptor.write(toFile: "\(sourceDirectory)/NetworkInterceptor.swift", atomically: true, encoding: .utf8)
    try! formData.write(toFile: "\(sourceDirectory)/FormData.swift", atomically: true, encoding: .utf8)
    try! dummyTest.write(toFile: "\(testDirectory)/DummyTest.swift", atomically: true, encoding: .utf8)

    if let globalHeaderFields = swaggerFile.globalHeaders?.map({
        ModelField(description: nil,
                   type: .string,
                   name: makeHeaderFieldName(headerName: $0),
                   required: true)
    }) {
        let globalHeaders = Model(serviceName: nil,
                                  description: nil,
                                  typeName: "GlobalHeaders",
                                  fields: globalHeaderFields,
                                  inheritsFrom: [],
                                  isInternalOnly: false)

        try! globalHeaders.toSwift(swaggerFile: swaggerFile)
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

        try! serviceDefinition.toSwift(swaggerFile: swaggerFile)
            .write(toFile: "\(serviceDirectory)/\(serviceDefinition.typeName).swift", atomically: true, encoding: .utf8)

        for type in serviceDefinition.innerTypes {
            let file = type.toSwift(swaggerFile: swaggerFile)
            let filename = "\(modelDirectory)/\(filePrefix)\(type.typeName).swift"
            try! file.write(toFile: filename, atomically: true, encoding: .utf8)
            if verbose {
                print("Wrote \(filename)")
            }
        }
    }

}
