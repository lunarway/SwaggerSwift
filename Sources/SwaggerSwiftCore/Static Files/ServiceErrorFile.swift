let serviceError = """
<ACCESSCONTROL> enum ServiceError<ErrorType>: Error {
    // The request failed, e.g. timeout
    case requestFailed(error: Error)
    // The backend returned an error, e.g. a 500 Internal Server Error, 403 Unauthorized
    case backendError(error: ErrorType)
}
"""
