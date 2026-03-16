import Foundation
import Stencil
import StencilSwiftKit

struct TemplateRenderer {
    private let environment: Environment

    init() {
        guard let resourceURL = Bundle.module.resourceURL else {
            fatalError("Templates resource bundle not found. Ensure SwaggerSwiftCore is built with SPM resources.")
        }
        let templateURL = resourceURL.appendingPathComponent("Templates")
        self.init(templateDirectory: templateURL)
    }

    init(templateDirectory: URL) {
        let loader = FileSystemLoader(paths: [.init(templateDirectory.path)])
        let ext = Extension()
        ext.registerStencilSwiftExtensions()
        ext.registerFilter("indented") { (value: Any?, arguments: [Any?]) in
            guard let string = value as? String else { return value }
            let level = (arguments.first as? Int) ?? 1
            let indent = String(repeating: "    ", count: level)
            return
                string
                .split(separator: "\n", omittingEmptySubsequences: false)
                .enumerated()
                .map { index, line in
                    if index == 0 { return String(line) }
                    if line.isEmpty { return "" }
                    return indent + line
                }
                .joined(separator: "\n")
        }
        self.environment = Environment(loader: loader, extensions: [ext])
    }

    func render(template name: String, context: [String: Any]) throws -> String {
        try environment.renderTemplate(name: name, context: context)
    }
}
