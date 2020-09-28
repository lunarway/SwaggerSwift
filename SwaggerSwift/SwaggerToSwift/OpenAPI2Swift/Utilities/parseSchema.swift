import SwaggerSwiftML

func parse(schema: Schema, allDefinitions: [String: Schema]) -> [SwiftProperty] {
//    let subschemaProperties = (schema.allOf ?? []).compactMap { allOf -> [SwiftProperty]? in
//        switch allOf.value {
//        case .reference(let ref):
//            guard let definitionName = ref.components(separatedBy: "/").last else { fatalError("Failed to find name of referenced definition") }
//            guard let referencedDefinition = allDefinitions[definitionName] else { fatalError("Failed to find referenced definition: \(definitionName)") }
//            return parse(schema: referencedDefinition, allDefinitions: allDefinitions)
//        case .node(let element):
//            return parse(properties: element.properties, required: element.required ?? [])
//        }
//    }.flatMap { $0 }

    switch schema.type {
    case .string(format: let format, enumValues: let enumValues, maxLength: let maxLength, minLength: let minLength, pattern: let pattern):
        
    case .number(format: let format, maximum: let maximum, exclusiveMaximum: let exclusiveMaximum, minimum: let minimum, exclusiveMinimum: let exclusiveMinimum, multipleOf: let multipleOf):
        <#code#>
    case .integer(format: let format, maximum: let maximum, exclusiveMaximum: let exclusiveMaximum, minimum: let minimum, exclusiveMinimum: let exclusiveMinimum, multipleOf: let multipleOf):
        <#code#>
    case .boolean:
        <#code#>
    case .array(_, collectionFormat: let collectionFormat, maxItems: let maxItems, minItems: let minItems, uniqueItems: let uniqueItems):
        <#code#>
    case .object(properties: let properties):
        <#code#>
    case .dictionary(valueType: let valueType, keys: let keys):
        <#code#>
    }

//    let properties = parse(properties: schema.properties, required: schema.required ?? [])
//
//    return properties + subschemaProperties
}
