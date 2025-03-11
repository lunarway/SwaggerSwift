import SwaggerSwiftML

extension SwaggerSwiftML.Operation {
    var isInternalOnly: Bool {
        if let value = self.customFields["x-internal"] {
            return value == "true"
        } else {
            return false
        }
    }
}
