import Foundation
import SwaggerSwiftML

/// Represents a Swift enum
struct Enumeration {
    let serviceName: String?
    let description: String?
    let typeName: String
    let values: [String]
    let isCodable: Bool
    let collectionFormat: CollectionFormat?

    private static let templateRenderer = TemplateRenderer()

    static func toCasename(_ str: String, _ isCodable: Bool) -> String {
        let str = isCodable ? str.camelized : str

        if SwiftKeyword(rawValue: str) != nil {
            return "`\(str)`"
        }

        if str.isNumber {
            return "_\(str)"
        }

        return str
    }

    func modelDefinition(embeddedFile _: Bool, accessControl: APIAccessControl) -> String {
        let enumCases =
            values
            .sorted(by: { $0 < $1 })
            .map { rawValue in
                [
                    "rawValue": rawValue,
                    "caseName": Self.toCasename(rawValue, isCodable),
                ]
            }

        var cases = enumCases.compactMap { $0["caseName"] }

        var unknownName = "unknown"
        if cases.contains(unknownName) {
            unknownName = "unknownCase"
        }

        if isCodable {
            cases += ["\(unknownName)(String)"]
        }

        let context: [String: Any] = [
            "accessControl": accessControl.rawValue,
            "typeName": typeName,
            "protocolConformanceSuffix": isCodable ? ": Codable, Equatable, Sendable" : ": Sendable",
            "cases": cases,
            "hasCodable": isCodable,
            "decodeCases": enumCases,
            "encodeCases": enumCases,
            "unknownName": unknownName,
        ]

        do {
            return try Self.templateRenderer.render(template: "Enumeration.stencil", context: context)
                .trimmingCharacters(in: .newlines)
        } catch {
            fatalError("Failed to render Enumeration \(typeName): \(error)")
        }
    }
}

extension Enumeration {
    func toSwift(
        serviceName: String?,
        embedded: Bool,
        accessControl: APIAccessControl,
        packagesToImport: [String]
    ) -> String {
        if embedded {
            return modelDefinition(embeddedFile: true, accessControl: accessControl)
        }

        var fileSections = ""
        fileSections += packagesToImport.map { "import \($0)" }.joined(separator: "\n")
        if let serviceName = serviceName {
            fileSections += "\n\nextension \(serviceName) {\n"
        }

        let modelDef = modelDefinition(embeddedFile: false, accessControl: accessControl)
        if let description = description, description.count > 0 {
            let comment = "// \(description.replacingOccurrences(of: "\n", with: "\n//"))"
            fileSections += "\(comment)\n\(modelDef)".indentLines(1) + "\n"
        } else {
            fileSections += modelDef.indentLines(1) + "\n"
        }

        if serviceName != nil {
            fileSections += "}"
        }

        return fileSections + "\n"
    }
}
