import SwaggerSwiftML

func parse(path: SwaggerSwiftML.Path, servicePath: String, swagger: Swagger, swaggerFile: SwaggerFile, verbose: Bool) -> ([NetworkRequestFunction], [ModelDefinition]) {
    let parameters: [Parameter] = (path.parameters ?? []).map {
        return swagger.findParameter(node: $0)
    }

    var functions = [NetworkRequestFunction]()
    var modelDefinitions = [ModelDefinition]()
    if let operation = path.get,
       let (parsedFunctions, parsedDefinitions) = parse(operation: operation, httpMethod: .get, servicePath: servicePath, parameters: parameters, swagger: swagger, swaggerFile: swaggerFile, verbose: verbose) {
        functions.append(parsedFunctions)
        modelDefinitions.append(contentsOf: parsedDefinitions)
    }

    if let operation = path.put,
       let (parsedFunctions, parsedDefinitions) = parse(operation: operation, httpMethod: .put, servicePath: servicePath, parameters: parameters, swagger: swagger, swaggerFile: swaggerFile, verbose: verbose) {
        functions.append(parsedFunctions)
        modelDefinitions.append(contentsOf: parsedDefinitions)
    }

    if let operation = path.post,
       let (parsedFunctions, parsedDefinitions) = parse(operation: operation, httpMethod: .post, servicePath: servicePath, parameters: parameters, swagger: swagger, swaggerFile: swaggerFile, verbose: verbose) {
        functions.append(parsedFunctions)
        modelDefinitions.append(contentsOf: parsedDefinitions)
    }

    if let operation = path.delete,
       let (parsedFunctions, parsedDefinitions) = parse(operation: operation, httpMethod: .delete, servicePath: servicePath, parameters: parameters, swagger: swagger, swaggerFile: swaggerFile, verbose: verbose) {
        functions.append(parsedFunctions)
        modelDefinitions.append(contentsOf: parsedDefinitions)
    }

    if let operation = path.options,
       let (parsedFunctions, parsedDefinitions) = parse(operation: operation, httpMethod: .options, servicePath: servicePath, parameters: parameters, swagger: swagger, swaggerFile: swaggerFile, verbose: verbose) {
        functions.append(parsedFunctions)
        modelDefinitions.append(contentsOf: parsedDefinitions)
    }

    if let operation = path.head,
       let (parsedFunctions, parsedDefinitions) = parse(operation: operation, httpMethod: .head, servicePath: servicePath, parameters: parameters, swagger: swagger, swaggerFile: swaggerFile, verbose: verbose) {
        functions.append(parsedFunctions)
        modelDefinitions.append(contentsOf: parsedDefinitions)
    }

    if let operation = path.patch,
       let (parsedFunctions, parsedDefinitions) = parse(operation: operation, httpMethod: .patch, servicePath: servicePath, parameters: parameters, swagger: swagger, swaggerFile: swaggerFile, verbose: verbose) {
        functions.append(parsedFunctions)
        modelDefinitions.append(contentsOf: parsedDefinitions)
    }

    return (functions, modelDefinitions)
}
