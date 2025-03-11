import Foundation
import SwaggerSwiftML

struct NotFound: Error {
    let reference: String
}

extension Swagger {
    /// The name of the service the Swagger file exposes
    var serviceName: String {
        info.title
            .components(separatedBy: CharacterSet.whitespaces.union(CharacterSet(charactersIn: "-")))
            .map { $0.uppercasingFirst }
            .joined()
    }

    func findParameter(node: Node<Parameter>) throws -> Parameter {
        switch node {
        case .reference(let reference):
            for (key, value) in self.parameters ?? [:] {
                let searchName = "#/parameters/\(key)"
                if reference == searchName {
                    return value
                }
            }

            throw NotFound(reference: reference)
        case .node(let node):
            return node
        }
    }

    func findSchema(reference: String) throws -> Schema {
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
                    return try findSchema(reference: reference)
                case .node(let schema):
                    return schema
                }
            }
        }

        throw NotFound(reference: reference)
    }
}
