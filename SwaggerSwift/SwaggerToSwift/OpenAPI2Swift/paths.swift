import SwaggerSwiftML

func make(paths swagger: Swagger) -> [SwiftMethod] {
    let pathMethods = swagger.paths.map { (endpoint, path) -> [SwiftMethod] in
        let pathName = endpoint.replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "{", with: "").replacingOccurrences(of: "}", with: "")

        var methods = [SwiftMethod]()
        if let post = path.post {
            methods.append(parsePath(baseUrl: swagger.basePath, httpMethod: "post", endpoint: endpoint, serviceName: pathName, path: path, request: post))
        }

        if let get = path.get {
            methods.append(parsePath(baseUrl: swagger.basePath, httpMethod: "get", endpoint: endpoint, serviceName: pathName, path: path, request: get))
        }

        if let put = path.put {
            methods.append(parsePath(baseUrl: swagger.basePath, httpMethod: "put", endpoint: endpoint, serviceName: pathName, path: path, request: put))
        }

        if let patch = path.patch {
            methods.append(parsePath(baseUrl: swagger.basePath, httpMethod: "patch", endpoint: endpoint, serviceName: pathName, path: path, request: patch))
        }

        if let delete = path.delete {
            methods.append(parsePath(baseUrl: swagger.basePath, httpMethod: "delete", endpoint: endpoint, serviceName: pathName, path: path, request: delete))
        }

        if let head = path.head {
            methods.append(parsePath(baseUrl: swagger.basePath, httpMethod: "head", endpoint: endpoint, serviceName: pathName, path: path, request: head))
        }

        if let options = path.options {
            methods.append(parsePath(baseUrl: swagger.basePath, httpMethod: "options", endpoint: endpoint, serviceName: pathName, path: path, request: options))
        }

        return methods
    }

    return pathMethods.flatMap { $0 }
}
