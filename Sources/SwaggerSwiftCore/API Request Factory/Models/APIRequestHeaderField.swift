/// A header field used in a single API request
struct APIRequestHeaderField {
    /// is the field required
    let isRequired: Bool
    /// The actual name of the header, e.g. x-OS
    let fullHeaderName: String

    /// The name of the field on the Swift type containing the object, e.g. xos
    var swiftyName: String {
        return APIRequestFactory().convertApiHeader(fullHeaderName)
    }

    init(headerName: String, isRequired: Bool) {
        self.fullHeaderName = headerName
        self.isRequired = isRequired
    }
}

extension Sequence where Element == APIRequestHeaderField {
    func asInitParameter() -> String {
        self.map { field in
            var declaration: String
            // myFieldName: FieldType
            declaration = "\(field.swiftyName): String"

            if field.isRequired == false {
                declaration += " = nil"
            }

            return declaration
        }.joined(separator: ", ")
    }

    func asPropertyList() -> String {
        self.sorted(by: { $0.swiftyName < $1.swiftyName }).map { field in
            let declaration = "public let \(field.swiftyName): String\(field.isRequired ? "" : "?")"
            return declaration
        }.joined(separator: "\n")
    }
}
