import Foundation
import SwaggerSwiftML

extension APIRequest {
    /// The arguments of the function, e.g. "myValue: String, myOtherValue: Int"
    private var functionArguments: String {
        parameters.map {
            let paramName = $0.name.variableNameFormatted
            let typeName = $0.typeName.toString(required: $0.required)

            let defaultValue: String
            if !$0.required {
                defaultValue = " = nil"
            } else {
                defaultValue = ""
            }

            return "\(paramName): \(typeName)\(defaultValue)"
        }.joined(separator: ", ")
    }

    private var forwardedArguments: String {
        parameters.map {
            let name = $0.name.variableNameFormatted
            return "\(name): \(name)"
        }.joined(separator: ", ")
    }

    private func makeRequestFunctionContext(
        serviceName: String?,
        swaggerFile: SwaggerFile,
        accessControl: String
    ) -> [String: Any] {
        let servicePath = self.servicePath.split(separator: "/")
            .map {
                let path = String($0)
                    .replacingOccurrences(of: "{", with: "")
                    .replacingOccurrences(of: "}", with: "")

                if $0.contains("{") {
                    return "\\(\(path.variableNameFormatted))"
                } else {
                    return path
                }
            }.joined(separator: "/")

        var globalHeaders = [String]()
        if swaggerFile.globalHeaders.count > 0 {
            globalHeaders.append("let globalHeaders = await self.headerProvider()")
            globalHeaders.append("globalHeaders.add(to: &request)")
        }

        let uniquelyGlobalHeaders = swaggerFile.globalHeaders.filter { globalHeaderName in
            headers.contains(where: { $0.fullHeaderName == globalHeaderName }) == false
        }

        let allHeaders =
            headers
            + uniquelyGlobalHeaders.map {
                APIRequestHeaderField(headerName: $0, isRequired: false)  // not required as they are default from the global header provider
            }

        let headersName = headers.filter { $0.isRequired }.count > 0 ? "headers" : "headers?"

        let setHeaderValues: [String] =
            allHeaders
            .sorted(by: { $0.swiftyName < $1.swiftyName })
            .map {
                if $0.isRequired {
                    return
                        "request.setValue(\(headersName).\($0.swiftyName), forHTTPHeaderField: \"\($0.fullHeaderName)\")"
                } else {
                    return """
                        if let \(($0.swiftyName)) = \(headersName).\($0.swiftyName) {
                            request.setValue(\($0.swiftyName), forHTTPHeaderField: \"\($0.fullHeaderName)\")
                        }
                        """
                }
            }

        var headerStatements = setHeaderValues

        var bodyInjection: String = ""
        if let body = parameters.first(where: { $0.in == .body }) {
            bodyInjection += """
                let jsonEncoder = JSONEncoder()
                jsonEncoder.dateEncodingStrategy = .iso8601
                request.httpBody = try? jsonEncoder.encode(\(body.name))
                """
        }

        if parameters.contains(where: { $0.in == .formData }) {
            bodyInjection += """
                let boundary = "Boundary-\\(UUID().uuidString)"
                request.setValue("multipart/form-data; boundary=\\(boundary)", forHTTPHeaderField: "Content-Type")

                var requestData = Data()

                """

            bodyInjection += parameters.filter { $0.in == .formData }.compactMap {
                switch $0.typeName {
                case .string:
                    return """
                        if let data = \($0.variableName).data(using: .utf8) {
                            requestData.append(FormData(data: data).toRequestData(named: "\($0.name)", using: boundary))
                        }

                        """
                case .int:
                    log("⚠️ Form data type 'int' is not yet supported", error: true)
                    return nil
                case .double:
                    log("⚠️ Form data type 'double' is not yet supported", error: true)
                    return nil
                case .float:
                    log("⚠️ Form data type 'float' is not yet supported", error: true)
                    return nil
                case .boolean:
                    log("⚠️ Form data type 'boolean' is not yet supported", error: true)
                    return nil
                case .int64:
                    log("⚠️ Form data type 'int64' is not yet supported", error: true)
                    return nil
                case .array:
                    log("⚠️ Form data type 'array' is not yet supported", error: true)
                    return nil
                case .enumeration(let typeName): fallthrough
                case .object(let typeName):
                    if typeName == "FormData" {
                        return
                            "requestData.append(\($0.name).toRequestData(named: \"\($0.name)\", using: boundary))"
                    } else if $0.isEnum {
                        return """
                            if let data = \($0.name).rawValue.data(using: .utf8) {
                                requestData.append(FormData(data: data).toRequestData(named: "\($0.name)", using: boundary))
                            }
                            """
                    } else {
                        log("⚠️ Form data type 'object' is not yet supported", error: true)
                        return nil
                    }
                case .date:
                    log("⚠️ Form data type 'date' is not yet supported", error: true)
                    return nil
                case .void:
                    log("⚠️ Form data type 'void' is not yet supported", error: true)
                    return nil
                case .typeAlias:
                    log("⚠️ Form data type 'typeAlias' is not yet supported", error: true)
                    return nil
                }
            }.joined(separator: "\n")

            bodyInjection += """

                if let endBoundaryData = "--\\(boundary)--".data(using: .utf8) {
                    requestData.append(endBoundaryData)
                }
                """
        }

        let requestDataArgument: String
        switch consumes {
        case .json:
            requestDataArgument = "nil"
            headerStatements.append(
                "request.setValue(\"application/json\", forHTTPHeaderField: \"Content-Type\")"
            )
        case .formUrlEncoded, .multiPartFormData:
            requestDataArgument = "requestData"
        }

        let requestPart =
            (globalHeaders.joined(separator: "\n").addNewlinesIfNonEmpty(2)
            + headerStatements.joined(separator: "\n").addNewlinesIfNonEmpty(2)
            + bodyInjection.addNewlinesIfNonEmpty(2))
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let responseTypes = self.responseTypes
            .map {
                $0.print(
                    apiName: serviceName ?? "",
                    errorType: returnType.failureType.toString(required: true)
                )
            }
            .joined(separator: "\n")

        let hasDecodableObjectResponse = self.responseTypes.contains { responseType in
            switch responseType {
            case .object(_, _, let typeName):
                return typeName != "Data"
            default:
                return false
            }
        }

        let failureType = returnType.failureType.toString(required: true)
        let decodeObjectHelper =
            hasDecodableObjectResponse
            ? """
            func _decodeObject<T: Decodable>(_ type: T.Type) throws(\(failureType)) -> T {
                do {
                    return try decoder.decode(T.self, from: data)
                } catch let error {
                    interceptor?.networkFailedToParseObject(
                        urlRequest: request,
                        urlResponse: response,
                        data: data,
                        error: error
                    )
                    throw \(failureType).requestFailed(error: error)
                }
            }
            """
            .trimmingCharacters(in: .newlines)
            : ""

        var functionDeclaration: String = "private func _\(functionName)"
        if swaggerFile.onlyAsync && !isInternalOnly {
            functionDeclaration = "\(accessControl) func \(functionName)"
        }

        var context: [String: Any] = [
            "functionDeclaration": functionDeclaration,
            "functionArguments": functionArguments,
            "failureType": failureType,
            "successType": returnType.successType.toString(required: true),
            "servicePath": servicePath,
            "hasQueries": !queries.isEmpty,
            "httpMethod": httpMethod.rawValue.uppercased(),
            "requestDataArgument": requestDataArgument,
            "responseTypesCode": responseTypes,
        ]

        let queryItemsCode = queries.toQueryItems()
        if !queryItemsCode.isEmpty { context["queryItemsCode"] = queryItemsCode }
        if !requestPart.isEmpty { context["requestPart"] = requestPart }
        if !decodeObjectHelper.isEmpty { context["decodeObjectHelper"] = decodeObjectHelper }

        return context
    }

    func toSwift(
        serviceName: String?,
        swaggerFile: SwaggerFile,
        embedded: Bool,
        accessControl: String,
        packagesToImport: [String],
        templateRenderer: TemplateRenderer
    ) throws -> String {
        let requestFunctionContext = makeRequestFunctionContext(
            serviceName: serviceName,
            swaggerFile: swaggerFile,
            accessControl: accessControl
        )

        let requestFunction = try templateRenderer.render(
            template: "APIRequestFunction.stencil",
            context: requestFunctionContext
        ).trimmingCharacters(in: .newlines)

        var documentation = """
            \(description?.documentationFormat() ?? "/// No description provided")
            /// - Endpoint: `\(self.httpMethod.rawValue.uppercased()) \(self.servicePath)`
            """

        if parameters.count > 0 {
            documentation += "\n"
            documentation += """
                /// - Parameters:
                \(parameters.map { "///   - \($0.variableName): \($0.description?.replacingOccurrences(of: "\n", with: ". ").replacingOccurrences(of: "..", with: ".") ?? "No description")" }.joined(separator: "\n"))
                """
        }

        let failureType = returnType.failureType.toString(required: true)
        let successType = returnType.successType.toString(required: true)

        var context: [String: Any] = [
            "documentation": documentation,
            "requestFunction": requestFunction,
            "isInternalOnly": isInternalOnly,
            "isDeprecated": isDeprecated,
            "renderWrappers": !swaggerFile.onlyAsync,
            "functionName": functionName,
            "functionArguments": functionArguments,
            "forwardedArguments": forwardedArguments,
            "successType": successType,
            "failureType": failureType,
            "accessControl": accessControl,
            "returnsVoid": successType == "Void",
        ]

        // Only set if true to simplify Stencil conditionals
        if !isInternalOnly { context.removeValue(forKey: "isInternalOnly") }
        if !isDeprecated { context.removeValue(forKey: "isDeprecated") }

        return try templateRenderer.render(
            template: "APIRequest.stencil",
            context: context
        )
    }
}

extension String {
    fileprivate func documentationFormat() -> String {
        trimmingCharacters(in: CharacterSet.newlines).components(separatedBy: "\n").map { "/// \($0)" }
            .joined(separator: "\n")
    }

    fileprivate func addNewlinesIfNonEmpty(_ count: Int = 1) -> String {
        if self.count > 0 {
            return self + String(repeating: "\n", count: count)
        } else {
            return self
        }
    }
}
