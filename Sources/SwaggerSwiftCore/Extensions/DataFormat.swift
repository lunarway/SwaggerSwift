import SwaggerSwiftML

extension DataFormat: @retroactive CustomStringConvertible {
  public var description: String {
    switch self {
    case .int32:
      return "Int"
    case .long:
      return "Int64"
    case .float:
      return "Float"
    case .double:
      return "Double"
    case .string:
      return "String"
    case .byte:
      return "String"
    case .binary:
      return "Data"
    case .boolean:
      return "Bool"
    case .date:
      return "Date"
    case .dateTime:
      return "Date"
    case .password:
      return "String"
    case .email:
      return "String"
    case .unsupported(let type):
      let type = type.lowercased()
      if type == "int64" {
        return "Int64"
      } else if type == "decimal" {
        return "Double"
      } else if type == "ISO8601" {
        return "Date"
      } else if type == "uri" {
        return "URL"
      } else if type == "int" {
        return "Int"
      } else if type == "integer" {
        return "Int"
      } else {
        fatalError("Unsupported type: \(type)")
      }
    }
  }
}
