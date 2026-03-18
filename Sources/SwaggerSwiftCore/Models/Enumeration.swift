import Foundation
import SwaggerSwiftML

/// Represents a Swift enum
struct Enumeration {
    let serviceName: String?
    let description: String?
    let typeName: String
    let values: [String]
    let isEncodable: Bool
    let isDecodable: Bool
    let collectionFormat: CollectionFormat?

    init(
        serviceName: String?,
        description: String?,
        typeName: String,
        values: [String],
        isCodable: Bool,
        collectionFormat: CollectionFormat?
    ) {
        self.init(
            serviceName: serviceName,
            description: description,
            typeName: typeName,
            values: values,
            isEncodable: isCodable,
            isDecodable: isCodable,
            collectionFormat: collectionFormat
        )
    }

    init(
        serviceName: String?,
        description: String?,
        typeName: String,
        values: [String],
        isEncodable: Bool,
        isDecodable: Bool,
        collectionFormat: CollectionFormat?
    ) {
        self.serviceName = serviceName
        self.description = description
        self.typeName = typeName
        self.values = values
        self.isEncodable = isEncodable
        self.isDecodable = isDecodable
        self.collectionFormat = collectionFormat
    }

    private static let templateRenderer = TemplateRenderer()

    var supportsCodableConformanceOptimization: Bool {
        isEncodable || isDecodable
    }

    func withConformance(isEncodable: Bool, isDecodable: Bool) -> Enumeration {
        Enumeration(
            serviceName: serviceName,
            description: description,
            typeName: typeName,
            values: values,
            isEncodable: isEncodable,
            isDecodable: isDecodable,
            collectionFormat: collectionFormat
        )
    }

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
        let hasRawValueSupport = isEncodable || isDecodable

        let enumCases =
            values
            .sorted(by: { $0 < $1 })
            .map { rawValue in
                [
                    "rawValue": rawValue,
                    "caseName": Self.toCasename(rawValue, hasRawValueSupport),
                ]
            }

        var cases = enumCases.compactMap { $0["caseName"] }

        var unknownName = "unknown"
        if cases.contains(unknownName) {
            unknownName = "unknownCase"
        }

        if hasRawValueSupport {
            cases += ["\(unknownName)(String)"]
        }

        let context: [String: Any] = [
            "accessControl": accessControl.rawValue,
            "typeName": typeName,
            "protocolConformanceSuffix": protocolConformanceSuffix,
            "cases": cases,
            "hasRawValueSupport": hasRawValueSupport,
            "isDecodable": isDecodable,
            "isEncodable": isEncodable,
            "decodeCases": enumCases,
            "encodeCases": enumCases,
            "unknownName": unknownName,
        ]

        do {
            return try Self.templateRenderer.render(template: "EnumerationBody.stencil", context: context)
                .trimmingCharacters(in: .newlines)
        } catch {
            fatalError("Failed to render Enumeration \(typeName): \(error)")
        }
    }

    private var protocolConformanceSuffix: String {
        switch (isEncodable, isDecodable) {
        case (true, true):
            return ": Codable, Equatable, Sendable"
        case (true, false):
            return ": Encodable, Equatable, Sendable"
        case (false, true):
            return ": Decodable, Equatable, Sendable"
        case (false, false):
            return ": Sendable"
        }
    }
}

extension Enumeration {
    func toSwift(
        serviceName: String?,
        embedded: Bool,
        accessControl: APIAccessControl,
        packagesToImport: [String],
        templateRenderer: TemplateRenderer
    ) throws -> String {
        let enumBody = modelDefinition(embeddedFile: embedded, accessControl: accessControl)

        let descriptionComment: String? =
            if let description = description, description.count > 0 {
                description.replacingOccurrences(of: "\n", with: "\n// ")
            } else {
                nil
            }

        var context: [String: Any] = [
            "embedded": embedded,
            "packagesToImport": packagesToImport,
            "enumBody": enumBody,
        ]
        if let serviceName { context["serviceName"] = serviceName }
        if let descriptionComment { context["description"] = descriptionComment }

        let rendered = try templateRenderer.render(template: "Enumeration.stencil", context: context)
        if embedded, rendered.hasSuffix("\n") {
            return String(rendered.dropLast())
        }

        return rendered
    }
}
