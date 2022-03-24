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

public extension URLQueryItem {
    init(name: String, value: Bool) {
        self.init(name: name, value: value ? "true" : "false")
    }

    init(name: String, value: Int) {
        self.init(name: name, value: String(value))
    }

    init(name: String, value: Int64) {
        self.init(name: name, value: String(value))
    }

    init(name: String, value: Double) {
        self.init(name: name, value: String(value))
    }

    init(name: String, value: Date) {
        self.init(name: name, value: ISO8601DateFormatter().string(from: value))
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

public protocol NetworkInterceptor {
    func networkWillPerformRequest(_ request: URLRequest) -> URLRequest
    func networkDidPerformRequest(urlRequest: URLRequest, urlResponse: URLResponse?, data: Data?, error: Error?) -> Bool
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
    private let crlf = "\\r\\n"

    /// the data representation of the object
    public let data: Data
    /// the mime type for the data, e.g. `image/png`
    public let mimeType: String?
    /// a filename representing the input - e.g. `image.png`
    public let filename: String?

    /// Creates the data part of a multi part request
    /// - Parameters:
    ///   - data: the piece of data being sent
    ///   - mimeType: the mime type for the data, e.g. `image/png`
    ///   - fileName: a filename representing the input - e.g. `image.png`
    public init(data: Data, mimeType: String? = nil, fileName: String? = nil) {
        self.data = data
        self.mimeType = mimeType
        self.filename = fileName
    }

    public func toRequestData(named fieldName: String, using boundary: String) -> Data {
        func append(string: String, toData data: inout Data) {
            guard let strData = string.data(using: .utf8) else { return }
            data.append(strData)
        }

        var contentDisposition = "Content-Disposition: form-data; name=\\"\\(fieldName)\\""
        if let filename = filename {
            contentDisposition += "; filename=\\"\\(filename)\\""
        }

        var mutableData = Data()

        append(string: "--\\(boundary)" + crlf, toData: &mutableData)
        append(string: contentDisposition + crlf, toData: &mutableData)
        if let mimeType = mimeType {
            append(string: "Content-Type: \\(mimeType)" + crlf + crlf, toData: &mutableData)
        } else {
            append(string: crlf, toData: &mutableData)
        }

        mutableData.append(data)

        append(string: crlf, toData: &mutableData)

        return mutableData as Data
    }
}
"""

let additionalPropertyUtil = """
import Foundation

public enum AdditionalProperty: Codable {
    case string(String)
    case integer(Int)
    case double(Double)
    case dictionary([String: AdditionalProperty])
    case array([AdditionalProperty])
    case bool(Bool)
    case null

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let stringValue = try? container.decode(String.self) {
            self = .string(stringValue)
        } else if let intValue = try? container.decode(Int.self) {
            self = .integer(intValue)
        } else if let doubleValue = try? container.decode(Double.self) {
            self = .double(doubleValue)
        } else if let dictionaryValue = try? container.decode([String: AdditionalProperty].self) {
            self = .dictionary(dictionaryValue)
        } else if let arrayValue = try? container.decode([AdditionalProperty].self) {
            self = .array(arrayValue)
        } else if let boolValue = try? container.decode(Bool.self) {
            self = .bool(boolValue)
        } else if container.decodeNil() {
            self = .null
        } else {
            throw DecodingError.typeMismatch(
                AdditionalProperty.self,
                DecodingError.Context(codingPath: container.codingPath,
                                      debugDescription: "AdditionalProperty contained un-supported value type")
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let stringValue):
            try container.encode(stringValue)
        case .integer(let value):
            try container.encode(value)
        case .double(let value):
            try container.encode(value)
        case .dictionary(let value):
            try container.encode(value)
        case .array(let value):
            try container.encode(value)
        case .bool(let value):
            try container.encode(value)
        case .null:
            try container.encodeNil()
        }
    }
}

"""

let dateDecodingStrategy = """
import Foundation

public func dateDecodingStrategy(_ decoder: Decoder) throws -> Date {
    let container = try decoder.singleValueContainer()
    let stringValue = try container.decode(String.self)

    // first try decoding date time format (yyyy-MM-ddTHH:mm:ssZ)
    let dateTimeFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [
            .withFullDate,
            .withDashSeparatorInDate,
            .withTime,
            .withColonSeparatorInTime
        ]
        return formatter
    }()

    if let date = dateTimeFormatter.date(from: stringValue) {
        return date
    }

    // then try decoding date only format (yyyy-MM-dd)
    let dateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [
            .withFullDate,
            .withDashSeparatorInDate
        ]
        return formatter
    }()

    if let date = dateFormatter.date(from: stringValue) {
        return date
    }

    throw DecodingError.dataCorruptedError(
        in: container,
        debugDescription: "Expected date string to be ISO8601-formatted."
    )
}
"""

// token
public func start(swaggerFilePath: String, token: String, destinationPath: String, projectName: String = "Services", verbose: Bool = false, apiList: [String]? = nil) throws {
    if verbose {
        print("Parsing swagger at \(swaggerFilePath)", to: &stdout)
    }

    let (swaggers, swaggerFile) = try SwaggerFileParser.parse(path: swaggerFilePath, authToken: token, apiList: apiList, verbose: verbose)

    if verbose {
        print("Creating Swift Project at \(destinationPath)")
    }

    let sharedTargetName = "\(projectName)Shared"
    try! createSwiftProject(at: destinationPath, named: projectName, sharedTargetName: sharedTargetName, targets: swaggers.map(\.serviceName))

    let sharedDirectory = [destinationPath, "Sources", sharedTargetName].joined(separator: "/")

    try FileManager.default.createDirectory(atPath: sharedDirectory,
                                    withIntermediateDirectories: true,
                                    attributes: nil)
    try! serviceError.write(toFile: "\(sharedDirectory)/ServiceError.swift", atomically: true, encoding: .utf8)
    try! urlQueryItemExtension.write(toFile: "\(sharedDirectory)/URLQueryExtension.swift", atomically: true, encoding: .utf8)
    try! parsingErrorExtension.write(toFile: "\(sharedDirectory)/ParsingError.swift", atomically: true, encoding: .utf8)
    try! networkInterceptor.write(toFile: "\(sharedDirectory)/NetworkInterceptor.swift", atomically: true, encoding: .utf8)
    try! additionalPropertyUtil.write(toFile: "\(sharedDirectory)/AdditionalProperty.swift", atomically: true, encoding: .utf8)
    try! formData.write(toFile: "\(sharedDirectory)/FormData.swift", atomically: true, encoding: .utf8)
    try! dateDecodingStrategy.write(toFile: "\(sharedDirectory)/DateDecodingStrategy.swift", atomically: true, encoding: .utf8)

    if let globalHeaderFields = swaggerFile.globalHeaders {
        let globalHeaders = GlobalHeadersModel(headerFields: globalHeaderFields)

        try! globalHeaders.toSwift(swaggerFile: swaggerFile)
            .write(toFile: "\(sharedDirectory)/GlobalHeaders.swift", atomically: true, encoding: .utf8)
    }

    for swagger in swaggers {
        if verbose {
            print("Parsing contents of Swagger: \(swagger.serviceName)", to: &stdout)
        }

        let serviceDirectory = [destinationPath, "Sources", swagger.serviceName].joined(separator: "/")
        let modelDirectory = "\(serviceDirectory)/Models"
        try? FileManager.default.removeItem(atPath: serviceDirectory)
        try? FileManager.default.removeItem(atPath: modelDirectory)
        try! FileManager.default.createDirectory(atPath: serviceDirectory, withIntermediateDirectories: true, attributes: nil)
        try! FileManager.default.createDirectory(atPath: modelDirectory, withIntermediateDirectories: true, attributes: nil)

        let serviceDefinition = parse(swagger: swagger, swaggerFile: swaggerFile, verbose: verbose)

        try! serviceDefinition.toSwift(serviceName: swagger.serviceName, swaggerFile: swaggerFile, embedded: false, packagesToImport: [sharedTargetName])
            .write(toFile: "\(serviceDirectory)/\(serviceDefinition.typeName).swift", atomically: true, encoding: .utf8)

        for type in serviceDefinition.innerTypes {
            let file = type.toSwift(serviceName: swagger.serviceName, swaggerFile: swaggerFile, embedded: false, packagesToImport: [sharedTargetName])
            let filename = "\(modelDirectory)/\(serviceDefinition.typeName)_\(type.typeName).swift"
            try! file.write(toFile: filename, atomically: true, encoding: .utf8)
            if verbose {
                print("Wrote \(filename)", to: &stdout)
            }
        }
    }
}
