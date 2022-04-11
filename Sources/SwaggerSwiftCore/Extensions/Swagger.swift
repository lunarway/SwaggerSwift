import Foundation
import SwaggerSwiftML

extension Swagger {
    /// The name of the service the Swagger file exposes
    var serviceName: String {
        info.title
            .components(separatedBy: CharacterSet.whitespaces.union(CharacterSet(charactersIn: "-")))
            .map { $0.uppercasingFirst }
            .joined()
    }

    func findParameter(node: Node<Parameter>) -> Parameter {
        switch node {
        case .reference(let reference):
            for (key, value) in self.parameters ?? [:] {
                let searchName = "#/parameters/\(key)"
                if reference == searchName {
                    return value
                }
            }

            fatalError("Failed to find parameter named: \(reference)")
        case .node(let node):
            return node
        }
    }

    func findSchema(reference: String) -> Schema? {
        for (key, value) in self.definitions ?? [:] {
            let searchName = "#/definitions/\(key)"
            if reference == searchName {
                return value
            }
        }

        for (key, value) in self.responses ?? [:] {
            let searchName = "#/responses/\(key)"
            if reference == searchName, let schemaNode = value.schema {
                switch schemaNode {
                case .reference(let reference):
                    return findSchema(reference: reference)
                case .node(let schema):
                    return schema
                }
            }
        }

        return nil
    }
}
