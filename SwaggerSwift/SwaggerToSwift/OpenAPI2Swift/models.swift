import Foundation
import SwaggerSwiftML

func make(models swagger: Swagger) -> [SwiftType] {
    let definitions = parseDefinitions(swagger.definitions, allDefinitions: swagger.definitions)
    let responses = parseResponseTypes(swagger.responses ?? [:], definitions: swagger.definitions)
    return (definitions + responses).sorted(by: { $0.typeName < $1.typeName })
}
