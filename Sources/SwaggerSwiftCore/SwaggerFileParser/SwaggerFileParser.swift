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

private struct SwaggerRequest {
    let branchName: String?
    let serviceName: String
    let request: URLRequest
}

struct SwaggerFileParser {
    static func parse(path: String, authToken: String, apiList: [String]? = nil, verbose: Bool) async throws -> ([Swagger], SwaggerFile) {
        guard let data = FileManager.default.contents(atPath: path) else {
            throw NSError(domain: "SwaggerFileParser", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to load SwaggerFile at \(path)"])
        }

        guard let swaggerFileText = String(data: data, encoding: .utf8) else {
            throw NSError(domain: "SwaggerFileParser", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to load data in SwaggerFile at \(path)"])
        }

        let swaggerFile: SwaggerFile = try YAMLDecoder().decode(from: swaggerFileText)

        let services = swaggerFile.services.filter { apiList?.contains($0.key) ?? true }

        let requests = services.map { service -> SwaggerRequest in
            let url = URL(string: "https://raw.githubusercontent.com/\(swaggerFile.organisation)/\(service.key)/\(service.value.branch ?? "master")/\(service.value.path ?? swaggerFile.path)")!
            if verbose {
                print("Downloading Swagger at: \(url.absoluteString)", to: &stdout)
            }

            var request = URLRequest(url: url)
            request.addValue("token \(authToken)", forHTTPHeaderField: "Authorization")
            request.addValue("application/vnd.github.v3.raw", forHTTPHeaderField: "Accept")
            return SwaggerRequest(branchName: service.value.branch, serviceName: service.key, request: request)
        }

        let swaggers: [Swagger] = try await withThrowingTaskGroup(of: Swagger?.self) { group in
            for request in requests {
                group.addTask {
                    do {
                        let (data, response) = try await URLSession.shared.data(for: request.request)
                        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                            print("[\(request.serviceName)]: Failed to download Swagger", to: &stderr)
                            if let branch = request.branchName {
                                print("[\(request.serviceName)]: ⚠️⚠️⚠️ The branch was defined as ´\(branch)´. Perhaps this branch is deleted now? ⚠️⚠️⚠️", to: &stderr)
                            }

                            print("- If this is happening to all of your services your github token might not be valid", to: &stderr)
                            print("- HTTP Status: \(httpResponse.statusCode)", to: &stderr)
                            print("- HTTP URL: \(httpResponse.url!.absoluteString)", to: &stderr)
                            return nil
                        }

                        let stringValue = String(data: data, encoding: .utf8)!

                        do {
                            let swagger = try SwaggerReader.read(text: stringValue)
                            return swagger
                        } catch let error {
                            print("[\(request.serviceName)]: 🚨🚨🚨 Failed to read Swagger for service: \(request.serviceName) 🚨🚨🚨 ", to: &stderr)
                            if let branch = request.branchName {
                                print("[\(request.serviceName)]: ⚠️⚠️⚠️ The branch was defined as ´\(branch)´. Perhaps this branch is broken now? ⚠️⚠️⚠️", to: &stderr)
                            }

                            print("🚨🚨🚨 \(error.localizedDescription)", to: &stderr)
                            return nil
                        }
                    } catch let error {
                        print("[\(request.serviceName)]: 🚨 Failed to download Swagger", to: &stderr)
                        print("[\(request.serviceName)]: 🚨 - \(error.localizedDescription)", to: &stderr)
                        return nil
                    }
                }
            }

            var swaggers = [Swagger]()
            for try await swagger in group {
                if let swagger = swagger {
                    swaggers.append(swagger)
                }
            }

            return swaggers
        }

        return (swaggers, swaggerFile)
    }
}
