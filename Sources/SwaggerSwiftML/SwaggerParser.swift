import Foundation
import Yams

public enum SwaggerError: Error {
    case fileNotFound
    case corruptFile
    case invalidPath
    case failedToParse(description: String, codingPath: [CodingKey])
}

public enum FileFormat {
    case json
    case yaml
}

public struct SwaggerReader {
    public static func readFile(atPath path: String, fileManager: FileManager = FileManager.default)
        throws -> Swagger
    {
        guard let swaggerFileData = fileManager.contents(atPath: path) else {
            throw SwaggerError.fileNotFound
        }

        guard let ymlString = String(data: swaggerFileData, encoding: .utf8) else {
            throw SwaggerError.corruptFile
        }

        guard let fileextension = path.components(separatedBy: ".").last else {
            throw SwaggerError.invalidPath
        }

        switch fileextension.lowercased() {
        case "json":
            return try JSONDecoder().decode(Swagger.self, from: swaggerFileData)
        case "yml", "yaml":
            return try YAMLDecoder().decode(Swagger.self, from: ymlString)
        default:
            throw SwaggerError.invalidPath
        }

    }

    public static func read(
        text: String,
        format: FileFormat = .yaml,
        fileManager: FileManager = FileManager.default
    ) throws -> Swagger {
        switch format {
        case .json:
            guard let data = text.data(using: .utf8) else {
                fatalError("Failed to convert string to data - what gives?")
            }
            return try JSONDecoder().decode(Swagger.self, from: data)
        case .yaml:
            return try YAMLDecoder().decode(Swagger.self, from: text)
        }
    }
}
