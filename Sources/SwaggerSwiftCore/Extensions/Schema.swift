import SwaggerSwiftML

extension Schema {
    var isInternalOnly: Bool {
        if let value = self.customFields["x-internal"] {
            return value == "true"
        } else {
            return false
        }
    }

    var overridesName: String? {
        if let value = self.customFields["x-override-name"] {
            return value
        } else {
            return nil
        }
    }
}
