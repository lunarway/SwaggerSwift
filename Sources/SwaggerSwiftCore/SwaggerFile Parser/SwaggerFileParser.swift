import Foundation
import SwaggerSwiftML
import Yams

struct SwaggerFileParser {
    static func parse(at path: String, fileManager: FileManager) throws -> SwaggerFile {
        guard fileManager.fileExists(atPath: path) else {
            throw NSError(
                domain: "SwaggerFileParser",
                code: 0,
                userInfo: [NSLocalizedDescriptionKey: "No SwaggerFile found"]
            )
        }

        guard let data = fileManager.contents(atPath: path) else {
            throw NSError(
                domain: "SwaggerFileParser",
                code: 0,
                userInfo: [NSLocalizedDescriptionKey: "Failed to load SwaggerFile at \(path)"]
            )
        }

        guard let swaggerFileText = String(data: data, encoding: .utf8) else {
            throw NSError(
                domain: "SwaggerFileParser",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Failed to load data in SwaggerFile at \(path)"]
            )
        }

        let swaggerFile: SwaggerFile = try YAMLDecoder().decode(from: swaggerFileText)

        return swaggerFile
    }
}
