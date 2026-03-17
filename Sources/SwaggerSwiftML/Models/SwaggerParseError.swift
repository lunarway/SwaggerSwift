enum SwaggerParseError: Error {
    case missingField
    case invalidField(String)
}
