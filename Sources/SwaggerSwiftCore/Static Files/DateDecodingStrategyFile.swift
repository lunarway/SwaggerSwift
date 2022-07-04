let dateDecodingStrategy = """
import Foundation

// first try decoding date time format (yyyy-MM-ddTHH:mm:ss.fffZ)
private let dateFractionalTimeFormatter: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [
        .withFullDate,
        .withDashSeparatorInDate,
        .withTime,
        .withColonSeparatorInTime,
        .withFractionalSeconds
    ]
    return formatter
}()

// then try decoding date time format (yyyy-MM-ddTHH:mm:ssZ)
private let dateTimeFormatter: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [
        .withFullDate,
        .withDashSeparatorInDate,
        .withTime,
        .withColonSeparatorInTime
    ]
    return formatter
}()

// then try decoding date only format (yyyy-MM-dd)
private let dateFormatter: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [
        .withFullDate,
        .withDashSeparatorInDate
    ]
    return formatter
}()

<ACCESSCONTROL> func dateDecodingStrategy(_ decoder: Decoder) throws -> Date {
    let container = try decoder.singleValueContainer()
    let stringValue = try container.decode(String.self)

    if let date = dateFractionalTimeFormatter.date(from: stringValue) {
        return date
    }

    if let date = dateTimeFormatter.date(from: stringValue) {
        return date
    }

    if let date = dateFormatter.date(from: stringValue) {
        return date
    }

    throw DecodingError.dataCorruptedError(
        in: container,
        debugDescription: "Expected date string to be ISO8601-formatted."
    )
}
"""
