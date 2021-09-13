import Foundation
import Yams
import SwaggerSwiftML

struct SwaggerFileParser {
    static func parse(path: String, authToken: String, apiList: [String]? = nil, verbose: Bool) throws -> ([Swagger], SwaggerFile) {
        guard let data = FileManager.default.contents(atPath: path) else {
            throw NSError(domain: "SwaggerFileParser", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to load SwaggerFile at \(path)"])
        }

        guard let swaggerFileText = String(data: data, encoding: .utf8) else {
            throw NSError(domain: "SwaggerFileParser", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to load data in SwaggerFile at \(path)"])
        }

        let swaggerFile: SwaggerFile = try! YAMLDecoder().decode(from: swaggerFileText)
        
        let services = swaggerFile.services.filter { apiList?.contains($0.key) ?? true }

        let requests = services.map { service -> URLRequest in
            let url = URL(string: "https://raw.githubusercontent.com/\(swaggerFile.organisation)/\(service.key)/\(service.value.branch ?? "master")/\(swaggerFile.path)")!
            if verbose {
                print("Downloading Swagger at: \(url.absoluteString)")
            }

            var request = URLRequest(url: url)
            request.addValue("token \(authToken)", forHTTPHeaderField: "Authorization")
            request.addValue("application/vnd.github.v3.raw", forHTTPHeaderField: "Accept")
            return request
        }

        let dispatchGroup = DispatchGroup()

        var files = [String]()
        for request in requests {
            dispatchGroup.enter()
            URLSession.shared.dataTask(with: request) { data, response, error in
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                    if continueOnFailedDownload {
                        print("Failed to download Swagger from: \(request.url?.absoluteString ?? "")")
                        print("If this is happening to all of your services your github token might not be valid")
                    }
                    dispatchGroup.leave()
                    return
                }

                files.append(String(data: data!, encoding: .utf8)!)
                dispatchGroup.leave()
            }.resume()
        }
        dispatchGroup.wait()

        return (try files.map {
            if verbose {
                print("Swagger File:")
                print($0)
            }

            return try SwaggerReader.read(text: $0)
        }, swaggerFile)
    }
}
