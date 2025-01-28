import SwaggerSwiftML

private struct AllOfPart {
  let typeName: String?
  let fields: [ModelField]
  let embedddedDefinitions: [ModelDefinition]
}

public class ObjectModelFactory {
  public var modelTypeResolver: ModelTypeResolver!

  public init() {
  }

  func make(
    properties: [String: Node<Schema>], requiredProperties: [String], allOf: [Node<Schema>]?,
    swagger: Swagger, typeNamePrefix: String, schema: Schema, namespace: String,
    customFields: [String: String]
  ) throws -> (TypeType, [ModelDefinition]) {
    let typeName = (customFields["x-override-name"] ?? schema.overridesName ?? typeNamePrefix)
      .modelNamed
      .split(separator: ".").map { String($0).uppercasingFirst }.joined()

    let propertyTypeName = "\(namespace).\(typeName)"
    let newNamespace = namespace + "." + typeName

    if let allOf = allOf, allOf.count > 0 {
      let allOfParts: [AllOfPart] = try parseAllOf(
        allOf: allOf,
        typeName: typeName,
        namespace: namespace,
        swagger: swagger)

      let embedddedDefinitions = allOfParts.flatMap { $0.embedddedDefinitions }
      let inherits = allOfParts.compactMap { $0.typeName }

      let model = Model(
        description: schema.description,
        typeName: typeName,
        fields: allOfParts.flatMap { $0.fields },
        inheritsFrom: inherits,
        isInternalOnly: schema.isInternalOnly,
        embeddedDefinitions: embedddedDefinitions,
        isCodable: true)

      return (.object(typeName: propertyTypeName), [.object(model)])
    } else {
      // when parsing the properties (fields) of a schema, there can be embedded models associated with the field
      let (resolvedProperties, inlineModels) = try resolveProperties(
        properties: properties,
        withRequiredProperties: requiredProperties + schema.required,
        namespace: newNamespace,
        swagger: swagger)

      let model = Model(
        description: schema.description,
        typeName: typeName,
        fields: resolvedProperties.sorted(by: { $0.safePropertyName < $1.safePropertyName }),
        inheritsFrom: [],
        isInternalOnly: schema.isInternalOnly,
        embeddedDefinitions: inlineModels,
        isCodable: true)

      return (.object(typeName: propertyTypeName), [.object(model)])
    }
  }

  private func resolveProperties(
    properties: [String: Node<Schema>], withRequiredProperties requiredProperties: [String],
    namespace: String, swagger: Swagger
  ) throws -> ([ModelField], [ModelDefinition]) {
    var totalFields = [ModelField]()
    var totalModels = [ModelDefinition]()

    for (name, schemaNode) in properties {
      if let (field, models) = try resolveProperty(
        named: name,
        namespace: namespace,
        schemaNode: schemaNode,
        withRequiredProperties: requiredProperties,
        swagger: swagger)
      {
        totalFields.append(field)
        totalModels.append(contentsOf: models)
      }
    }

    return (totalFields, totalModels)
  }

  private func resolveProperty(
    named: String, namespace: String, schemaNode: Node<Schema>,
    withRequiredProperties requiredProperties: [String], swagger: Swagger
  ) throws -> (ModelField, [ModelDefinition])? {
    let isRequired = requiredProperties.contains(named)

    switch schemaNode {
    case .reference(let reference):
      let schema = try swagger.findSchema(reference: reference)
      let modelReference = try ModelReference(rawValue: reference)

      var typeName: String
      if modelReference.typeName == "Type" {
        typeName = "Type\(named.uppercasingFirst)"
          .modelNamed
          .split(separator: ".").map { String($0).uppercasingFirst }.joined()
      } else {
        typeName = modelReference.typeName
      }

      // since this is a referenced object is must be something that is available from the top level nested types
      typeName = "\(swagger.serviceName).\(typeName)"

      // since this is a referenced object that is globally defined,
      // then the global reference will always be a typealias (or an object), and
      // can therefore be refered to as an object type
      let field = ModelField(
        description: schema.description,
        type: .object(typeName: typeName),
        name: named,
        isRequired: isRequired)

      return (field, [])
    case .node(let schema):
      var fieldTypeName = "\(named.uppercasingFirst)"
      if fieldTypeName == "Type" {
        fieldTypeName = "\(fieldTypeName)\(named.uppercasingFirst)"
      }

      fieldTypeName = fieldTypeName.modelNamed

      let resolvedType = try modelTypeResolver.resolve(
        forSchema: schema,
        typeNamePrefix: fieldTypeName,
        namespace: namespace,
        swagger: swagger)

      let modelField = ModelField(
        description: schema.description,
        type: resolvedType.propertyType,
        name: named,
        isRequired: isRequired || schema.required.contains(named))

      return (modelField, resolvedType.inlineModelDefinitions)
    }
  }

  private func parseAllOf(
    allOf: [Node<Schema>], typeName: String, namespace: String, swagger: Swagger
  ) throws -> [AllOfPart] {
    var allOfParts = [AllOfPart]()

    for allOf in allOf {
      switch allOf {
      case .reference(let reference):
        let schema = try swagger.findSchema(reference: reference)

        guard case SchemaType.object = schema.type else {
          log(
            "[\(typeName)] Non object type received as a part of an all of statement", error: true)
          continue
        }

        let modelReference = try ModelReference(rawValue: reference)

        let part = AllOfPart(
          typeName: modelReference.typeName,
          fields: [],
          embedddedDefinitions: [])

        allOfParts.append(part)
      case .node(let schema):
        guard case let SchemaType.object(properties, allOfItems) = schema.type else {
          fatalError("Not implemented")
        }

        if let allOfItems = allOfItems, allOfItems.count > 0 {
          log("There is allOf items present but it is not currently supported")
        }

        var allFields = [ModelField]()
        var allInlineModels = [ModelDefinition]()

        for property in properties {
          if let (field, inlineModels) = try parseAllOfPartProperty(
            named: property.key,
            propertySchema: property.value,
            requiredProperties: schema.required,
            namespace: namespace,
            swagger: swagger)
          {

            allFields.append(field)
            allInlineModels.append(contentsOf: inlineModels)
          }
        }

        let allOfPart = AllOfPart(
          typeName: nil,
          fields: allFields,
          embedddedDefinitions: allInlineModels)

        allOfParts.append(allOfPart)
      }
    }

    return allOfParts
  }

  private func parseAllOfPartProperty(
    named name: String, propertySchema: Node<Schema>, requiredProperties: [String],
    namespace: String, swagger: Swagger
  ) throws -> (ModelField, [ModelDefinition])? {
    let isRequired = requiredProperties.contains(name)

    switch propertySchema {
    case .reference(let reference):
      let schema = try swagger.findSchema(reference: reference)

      let typeName = reference.components(separatedBy: "/").last ?? ""
      if case SchemaType.object = schema.type {
        let field = ModelField(
          description: schema.description,
          type: .object(typeName: typeName),
          name: name,
          isRequired: isRequired)

        return (field, [])
      } else {
        let resolvedType = try modelTypeResolver.resolve(
          forSchema: schema,
          typeNamePrefix: typeName,
          namespace: namespace,
          swagger: swagger)

        let field = ModelField(
          description: schema.description,
          type: resolvedType.propertyType,
          name: name,
          isRequired: isRequired)

        return (field, resolvedType.inlineModelDefinitions)
      }
    case .node(let schema):
      let resolvedType = try modelTypeResolver.resolve(
        forSchema: schema,
        typeNamePrefix: name.modelNamed,
        namespace: namespace,
        swagger: swagger)

      let field = ModelField(
        description: schema.description,
        type: resolvedType.propertyType,
        name: name,
        isRequired: isRequired)

      return (field, resolvedType.inlineModelDefinitions)
    }
  }
}
