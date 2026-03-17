import Foundation

/// Represents some kind of network model. This could be a response type or a request type.
struct GlobalHeadersModel {
    let typeName = "GlobalHeaders"
    let headerFields: [String]

    private func sortedFields() -> [[String: Any]] {
        headerFields
            .map { APIRequestHeaderField(headerName: $0, isRequired: false) }
            .sorted(by: { $0.swiftyName < $1.swiftyName })
            .map { ["swiftyName": $0.swiftyName, "fullHeaderName": $0.fullHeaderName] }
    }

    public func writeExtensions(inCommonPackageNamed: String?, templateRenderer: TemplateRenderer) throws -> String {
        let context: [String: Any] = [
            "typeName": typeName,
            "fields": sortedFields(),
            "commonPackageName": inCommonPackageNamed as Any,
        ]

        return try templateRenderer.render(template: "GlobalHeaderExtensions.stencil", context: context)
    }
}

extension GlobalHeadersModel {
    func toSwift(templateRenderer: TemplateRenderer) throws -> String {
        let context: [String: Any] = [
            "typeName": typeName,
            "fields": sortedFields(),
        ]

        return try templateRenderer.render(template: "GlobalHeaders.stencil", context: context)
    }
}
