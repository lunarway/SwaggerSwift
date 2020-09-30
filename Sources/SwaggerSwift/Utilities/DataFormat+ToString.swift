import SwaggerSwiftML

extension DataFormat {
    var toString: String {
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
            if type == "int64" {
                return "Int64"
            } else if type == "decimal" {
                return "Double"
            } else if type == "ISO8601" {
                return "Date"
            } else {
                fatalError("Unsupported type: \(type)")
            }
        }
    }
}
