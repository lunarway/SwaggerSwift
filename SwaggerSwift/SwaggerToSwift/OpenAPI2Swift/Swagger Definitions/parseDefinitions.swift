import SwaggerSwiftML

func parseDefinitions(_ definitions: [String: Schema], allDefinitions: [String: Schema]) -> [SwiftType] {
    return definitions.map { name, schema in
        let properties = parse(schema: schema, allDefinitions: allDefinitions)

        if let enumType = schema.enum {
            return SwiftEnum(typeName: name, options: enumType)
        } else {
            return SwiftCodableStruct(documentation: schema.description, typeName: name, properties: properties)
        }
    }
}

