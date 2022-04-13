import SwaggerSwiftML

extension Path {
    func operationForMethod(_ httpMethod: HTTPMethod) -> Operation? {
        switch httpMethod {
        case .get:
            return self.get
        case .put:
            return self.put
        case .post:
            return self.post
        case .delete:
            return self.delete
        case .patch:
            return self.patch
        case .options:
            return self.options
        case .head:
            return self.head
        }
    }
}
