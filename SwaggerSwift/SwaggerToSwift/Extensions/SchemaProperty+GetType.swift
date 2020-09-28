import SwaggerSwiftML
import os.log

let logger = OSLog(subsystem: "Swagger2Swift", category: .pointsOfInterest)

//func getType(from type: PropertyType, format: PropertyFormat?, items: Reference?) -> String? {
//    switch type {
//    case .string:
//        if let format = format {
//            switch format {
//            case .ISO8601:
//                return "Date"
//            case .uuid:
//                return "String"
//            default:
//                fatalError("Invalid number format received: \(format)")
//            }
//        }
//        return "String"
//    case .boolean:
//        return "Bool"
//    case .integer:
//        if let format = format {
//            switch format {
//            case .int32:
//                return "Int"
//            case .int64:
//                return "Int64"
//            default:
//                fatalError("Invalid number format received: \(format)")
//            }
//        }
//        return "Int"
//
//    case .number:
//        if let format = format {
//            switch format {
//            case .int32:
//                os_log(.error, "int32 should not appear in number according to Swagger 2.0 spec")
//                return "Int"
//            case .int64:
//                os_log(.error, "int64 should not appear in number according to Swagger 2.0 spec")
//                return "Int64"
//            case .float:
//                return "Float"
//            case .double:
//                return "Double"
//            default:
//                fatalError("Invalid number format received: \(format)")
//            }
//        }
//
//        return "Int"
//    case .array:
//        return "[\(items!.ref.components(separatedBy: "/").last!)]"
//    case .object:
//        return nil
//    case .enum:
//        fatalError("This is handled elsewhere")
//    }
//}
