// describes a single network request function
struct APIRequest {
    let description: String?
    let functionName: String
    let parameters: [FunctionParameter]
    let `throws`: Bool
    let consumes: APIRequestConsumes
    let isInternalOnly: Bool
    let isDeprecated: Bool

    let httpMethod: HTTPMethod
    let servicePath: String

    /// URLQueryItems
    let queries: [QueryElement]
    let headers: [APIRequestHeaderField]
    let responseTypes: [APIRequestResponseType]
}
