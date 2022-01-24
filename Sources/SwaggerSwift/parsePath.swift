import SwaggerSwiftML

func parse(path: SwaggerSwiftML.Path, servicePath: String, swagger: Swagger, swaggerFile: SwaggerFile, verbose: Bool) -> ([NetworkRequestFunction], [ModelDefinition]) {
    let parameters: [Parameter] = (path.parameters ?? []).map {
        return swagger.findParameter(node: $0)
    }

    var functions = [NetworkRequestFunction]()
    var modelDefinitions = [ModelDefinition]()
    if let operation = path.get,
       let result = parse(operation: operation, httpMethod: .get, servicePath: servicePath, parameters: parameters, swagger: swagger, swaggerFile: swaggerFile, verbose: verbose) {
        functions.append(result.0)
        modelDefinitions.append(contentsOf: result.1)
    }

    if let operation = path.put,
       let result = parse(operation: operation, httpMethod: .put, servicePath: servicePath, parameters: parameters, swagger: swagger, swaggerFile: swaggerFile, verbose: verbose) {
        functions.append(result.0)
        modelDefinitions.append(contentsOf: result.1)
    }

    if let operation = path.post,
       let result = parse(operation: operation, httpMethod: .post, servicePath: servicePath, parameters: parameters, swagger: swagger, swaggerFile: swaggerFile, verbose: verbose) {
        functions.append(result.0)
        modelDefinitions.append(contentsOf: result.1)
    }

    if let operation = path.delete,
       let result = parse(operation: operation, httpMethod: .delete, servicePath: servicePath, parameters: parameters, swagger: swagger, swaggerFile: swaggerFile, verbose: verbose) {
        functions.append(result.0)
        modelDefinitions.append(contentsOf: result.1)
    }

    if let operation = path.options,
       let result = parse(operation: operation, httpMethod: .options, servicePath: servicePath, parameters: parameters, swagger: swagger, swaggerFile: swaggerFile, verbose: verbose) {
        functions.append(result.0)
        modelDefinitions.append(contentsOf: result.1)
    }

    if let operation = path.head,
       let result = parse(operation: operation, httpMethod: .head, servicePath: servicePath, parameters: parameters, swagger: swagger, swaggerFile: swaggerFile, verbose: verbose) {
        functions.append(result.0)
        modelDefinitions.append(contentsOf: result.1)
    }

    if let operation = path.patch,
       let result = parse(operation: operation, httpMethod: .patch, servicePath: servicePath, parameters: parameters, swagger: swagger, swaggerFile: swaggerFile, verbose: verbose) {
        functions.append(result.0)
        modelDefinitions.append(contentsOf: result.1)
    }

    return (functions, modelDefinitions)
}
