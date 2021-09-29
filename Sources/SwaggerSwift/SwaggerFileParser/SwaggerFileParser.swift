import Foundation
import Yams
import SwaggerSwiftML

struct StdOut: TextOutputStream {
    let stdout = FileHandle.standardOutput

    func write(_ string: String) {
        guard let data = string.data(using: .utf8) else {
            fatalError() // encoding failure: handle as you wish
        }
        stdout.write(data)
    }
}

struct StdErr: TextOutputStream {
    let stderr = FileHandle.standardError

    func write(_ string: String) {
        guard let data = string.data(using: .utf8) else {
            fatalError() // encoding failure: handle as you wish
        }
        stderr.write(data)
    }
}

var stdout = StdOut()
var stderr = StdErr()

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

        let requests = services.map { service -> (branch: Service, serviceName: String, request: URLRequest) in
            let url = URL(string: "https://raw.githubusercontent.com/\(swaggerFile.organisation)/\(service.key)/\(service.value.branch ?? "master")/\(swaggerFile.path)")!
            if verbose {
                print("Downloading Swagger at: \(url.absoluteString)", to: &stdout)
            }

            var request = URLRequest(url: url)
            request.addValue("token \(authToken)", forHTTPHeaderField: "Authorization")
            request.addValue("application/vnd.github.v3.raw", forHTTPHeaderField: "Accept")
            return (service.value.branch, service.key, request)
        }

        let dispatchGroup = DispatchGroup()

        var files = [String]()
        for request in requests {
            dispatchGroup.enter()
            URLSession.shared.dataTask(with: request.2) { data, response, error in
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                    print("Failed to download Swagger for \(request.1)", to: &stderr)
                    if request.branch !== "master" || request.branch !== "main" {
                        print("⚠️⚠️⚠️ The branch was defined as ´\(request.branch)´. Perhaps this branch is deleted now? ⚠️⚠️⚠️", to: &stderr)
                    }

                    print("- If this is happening to all of your services your github token might not be valid", to: &stderr)
                    print("- HTTP Status: \(httpResponse.statusCode)", to: &stderr)
                    print("- HTTP URL: \(httpResponse.url!.absoluteString)", to: &stderr)
                    dispatchGroup.leave()
                    return
                }

                if let data = data {
                    files.append(String(data: data, encoding: .utf8)!)
                }

                dispatchGroup.leave()
            }.resume()
        }
        dispatchGroup.wait()

        return (try files.map {
            if verbose {
                print("Swagger File:", to: &stdout)
                print($0, to: &stderr)
            }

            return try SwaggerReader.read(text: $0)
        }, swaggerFile)
    }
}
