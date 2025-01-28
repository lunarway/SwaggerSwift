import Foundation

/// Represents a single field on a Model
struct ModelField {
  let description: String?
  let type: TypeType
  let isRequired: Bool
  let argumentLabel: String
  let safePropertyName: SafePropertyName
  let safeParameterName: SafeParameterName
  let defaultValue: String?

  /// Tells whether the field name present in the final Swift model is the same as the one used in the Swagger
  var usesSwaggerFieldName: Bool {
    let nameWasSafe = safeParameterName.value == argumentLabel
    let nameMatchesVariableNameFormatting =
      safeParameterName.value.variableNameFormatted == argumentLabel

    return nameWasSafe && nameMatchesVariableNameFormatting
  }

  init(description: String?, type: TypeType, name: String, isRequired: Bool) {
    self.description = description
    self.type = type
    self.argumentLabel = name
    self.safePropertyName = SafePropertyName(name)
    self.safeParameterName = SafeParameterName(name)
    self.isRequired = isRequired

    switch type {
    case .string(let defaultValue):
      if let defaultValue = defaultValue {
        self.defaultValue = "\"\(defaultValue)\""
      } else {
        self.defaultValue = nil
      }
    case .int(let defaultValue):
      if let defaultValue = defaultValue {
        self.defaultValue = String(defaultValue)
      } else {
        self.defaultValue = nil
      }
    case .int64(let defaultValue):
      if let defaultValue = defaultValue {
        self.defaultValue = String(defaultValue)
      } else {
        self.defaultValue = nil
      }
    case .double(let defaultValue):
      if let defaultValue = defaultValue {
        self.defaultValue = String(defaultValue)
      } else {
        self.defaultValue = nil
      }
    case .float(let defaultValue):
      if let defaultValue = defaultValue {
        self.defaultValue = String(defaultValue)
      } else {
        self.defaultValue = nil
      }
    case .boolean(let defaultValue):
      if let defaultValue = defaultValue {
        if defaultValue {
          self.defaultValue = "true"
        } else {
          self.defaultValue = "false"
        }
      } else {
        self.defaultValue = nil
      }
    case .array:
      self.defaultValue = nil
    case .object:
      self.defaultValue = nil
    case .enumeration:
      self.defaultValue = nil
    case .date:
      self.defaultValue = nil
    case .void:
      self.defaultValue = nil
    case .typeAlias:
      self.defaultValue = nil
    }
  }
}

extension Sequence where Element == ModelField {
  func asInitParameter() -> String {
    self.map { field in
      let fieldType =
        "\(field.type.toString(required: field.isRequired || field.defaultValue != nil))"

      var declaration: String
      if field.argumentLabel.variableNameFormatted
        != field.safeParameterName.value.variableNameFormatted.trimmingCharacters(
          in: CharacterSet(charactersIn: "`"))
      {
        // MyFieldName myFieldName: FieldType
        declaration =
          "\(field.argumentLabel.variableNameFormatted) \(field.safeParameterName.value.variableNameFormatted): \(fieldType)"
      } else {
        // myFieldName: FieldType
        declaration = "\(field.safeParameterName.value.variableNameFormatted): \(fieldType)"
      }

      if let defaultValue = field.defaultValue {
        declaration += " = " + defaultValue
      }

      if field.isRequired == false && field.defaultValue == nil {
        declaration += " = nil"
      }

      return declaration
    }.joined(separator: ", ")
  }

  func asPropertyList(accessControl: APIAccessControl) -> String {
    self.sorted(by: { $0.argumentLabel < $1.argumentLabel }).map { field in
      let declaration =
        "\(accessControl.rawValue) let \(field.safePropertyName.value.variableNameFormatted): \(field.type.toString(required: field.isRequired || field.defaultValue != nil))"
      if let description = field.description {
        return """
          \(description.components(separatedBy: "\n").filter { $0.isEmpty == false }.map { "// \($0)" }.joined(separator: "\n").trimmingCharacters(in: CharacterSet.whitespacesAndNewlines))
          \(declaration)
          """
      } else {
        return declaration
      }
    }.joined(separator: "\n")
  }
}
