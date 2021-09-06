import Foundation

internal func dateDecodingStrategy(_ decoder: Decoder) throws -> Date {
    let container = try decoder.singleValueContainer()
    let stringValue = try container.decode(String.self)

    // first try decoding date time format (yyyy-MM-ddTHH:mm:ssZ)
    let dateTimeFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [
            .withFullDate,
            .withDashSeparatorInDate,
            .withTime,
            .withColonSeparatorInTime
        ]
        return formatter
    }()

    if let date = dateTimeFormatter.date(from: stringValue) {
        return date
    }

    // then try decoding date only format (yyyy-MM-dd)
    let dateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [
            .withFullDate,
            .withDashSeparatorInDate
        ]
        return formatter
    }()

    if let date = dateFormatter.date(from: stringValue) {
        return date
    }

    throw DecodingError.dataCorruptedError(
        in: container,
        debugDescription: "Expected date string to be ISO8601-formatted."
    )
}
