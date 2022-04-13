struct QueryElement {
    enum ValueType {
        case date
        case `enum`
        case `default`
    }

    let fieldName: String
    let fieldValue: String
    let isOptional: Bool
    let valueType: ValueType
}

extension QueryElement {
    func toString() -> String {
        let fieldName = self.fieldName.camelized
        if self.isOptional {
            let fieldValue: String
            switch self.valueType {
            case .enum:
                fieldValue = "\(self.fieldValue)?.rawValue"
            case .date:
                return """
                    if let \(fieldName)Value = \(self.fieldName) {
                        queryItems.append(URLQueryItem(name: \"\(self.fieldName)\", value: \(fieldName)Value))
                    }
                    """
            default:
                fieldValue = "\(self.fieldValue)"
            }

            return """
                if let \(fieldName)Value = \(fieldValue) {
                    queryItems.append(URLQueryItem(name: \"\(self.fieldName)\", value: \(fieldName)Value))
                }
                """
        } else {
            let fieldValue: String
            switch self.valueType {
            case .enum:
                fieldValue = "\(self.fieldValue).rawValue"
            default:
                fieldValue = "\(self.fieldValue)"
            }

            return "queryItems.append(URLQueryItem(name: \"\(self.fieldName)\", value: \(fieldValue)))"
        }
    }
}

extension Sequence where Element == QueryElement {
    func toQueryItems() -> String {
        if self.underestimatedCount > 0 {
            let queryItems = self.map {
                $0.toString()
            }.joined(separator: "\n")

            return """
        var queryItems = [URLQueryItem]()
        \(queryItems)
        urlComponents.queryItems = queryItems
        """
        } else {
            return ""
        }
    }
}
