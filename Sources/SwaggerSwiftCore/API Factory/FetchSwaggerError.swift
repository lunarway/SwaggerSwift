enum FetchSwaggerError: Error {
    case requestFailed(serviceName: String, branch: String, statusCode: Int)
    case invalidResponse(serviceName: String)
    case couldNotParse(serviceName: String, Error)

    func logError() {
        switch self {
        case .requestFailed(let serviceName, let branch, let statusCode):
            log("[\(serviceName)]: Failed to download Swagger", error: true)
            if branch != "master" {
                log(
                    "[\(serviceName)]: ⚠️⚠️⚠️ The branch was defined as ´\(branch)´. Perhaps this branch is deleted now? ⚠️⚠️⚠️",
                    error: true
                )
            }

            log(
                "[\(serviceName)]: - If this is happening to all of your services your github token might not be valid",
                error: true
            )
            log("[\(serviceName)]: - HTTP Status: \(statusCode)", error: true)
        case .invalidResponse(let serviceName):
            log("[\(serviceName)]: 🚨🚨🚨 Swagger data was invalid", error: true)
        case .couldNotParse(let serviceName, let error):
            log("[\(serviceName)]: 🚨🚨🚨 Failed to read Swagger", error: true)
            log("[\(serviceName)]: 🚨🚨🚨 \(error.localizedDescription)", error: true)
        }
    }
}
