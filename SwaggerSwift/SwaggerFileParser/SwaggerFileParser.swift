import Foundation
import Yams
import SwaggerSwiftML

struct SwaggerFileParser {
    static func parse(path: String, authToken: String) throws -> [Swagger] {
        let data = FileManager.default.contents(atPath: path)!
        let swaggerFileText = String(data: data, encoding: .utf8)!

        let swaggerFile: SwaggerFile = try! YAMLDecoder().decode(from: swaggerFileText)

        let requests = swaggerFile.services.map { service -> URLRequest in
            let url = URL(string: "https://raw.githubusercontent.com/\(swaggerFile.organisation)/\(service.key)/\(service.value.branch ?? "master")/\(swaggerFile.path)")!
            var request = URLRequest(url: url)
            request.addValue("token \(authToken)", forHTTPHeaderField: "Authorization")
            request.addValue("application/vnd.github.v3.raw", forHTTPHeaderField: "Accept")
            return request
        }

        let dispatchGroup = DispatchGroup()

        var files = [String]()
        for request in requests {
            dispatchGroup.enter()
            URLSession.shared.dataTask(with: request) { mah, mah2, mah3 in
                files.append(String(data: mah!, encoding: .utf8)!)
                dispatchGroup.leave()
            }.resume()
        }
        dispatchGroup.wait()

        return try files.map {
            try SwaggerReader.read(text: $0)
        }
    }
}
