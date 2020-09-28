import SwaggerSwiftML

func parseResponseTypes(_ responses: [String: Response], definitions: [String: Schema]) -> [SwiftType] {
    return responses.map { name, response in
        assert(response.schema.ref.hasPrefix("#/definitions/"), "This might be a wrong assumption - instead if referenced: \(response.schema.ref)")
        let definitionName = response.schema.ref.components(separatedBy: "/").last!
        guard let schema = definitions[definitionName] else {
            fatalError("Response mapped to an unknown definition: \(definitionName)")
        }

        let properties = parse(schema: schema, allDefinitions: definitions)

        if let enumType = schema.enum {
            return SwiftEnum(typeName: name, options: enumType)
        } else {
            return SwiftCodableStruct(documentation: response.description, typeName: name, properties: properties)
        }
    }
}

