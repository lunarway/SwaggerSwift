import Foundation
import SwaggerSwiftML

enum ParamLocation {
  case query
  case header
  case path
  case formData
  case body
}

struct HeaderParameter {
  let type: ParameterType
  let name: String
  let required: Bool
  let description: String?
}

extension Sequence where Element == SwaggerSwiftML.Parameter {
  /// Convenience function that searches a set of SwaggerSwiftML.Parameter's to find those that are used in a specific location, based on `ParamLocation`
  /// - Parameter type: the type of api parameter that is needed
  /// - Returns: the set of api parameters usin in a specific api location, see `ParamLocation`
  func parameters(of type: ParamLocation) -> [(Parameter, SwaggerSwiftML.ParameterType, Bool?)] {
    return self.compactMap {
      switch $0.location {
      case .query(let paramType, let allowEmpty):
        if type == .query {
          return ($0, paramType, allowEmpty)
        } else {
          return nil
        }
      case .header(let paramType):
        if type == .header {
          return ($0, paramType, nil)
        } else {
          return nil
        }
      case .path(let paramType):
        if type == .path {
          return ($0, paramType, nil)
        } else {
          return nil
        }
      case .formData(let paramType, let allowEmpty):
        if type == .formData {
          return ($0, paramType, allowEmpty)
        } else {
          return nil
        }
      case .body:
        // This cannot be filtered on in this utility - body has no param type and so
        // it makes little sense to return anything from this")
        return nil
      }
    }
  }
}
