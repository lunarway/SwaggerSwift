let dateDecodingStrategy = """
  import Foundation

  @Sendable package func dateDecodingStrategy(_ decoder: any Decoder) throws -> Date {
      let container = try decoder.singleValueContainer()
      let stringValue = try container.decode(String.self)

      // first try decoding date time format (yyyy-MM-ddTHH:mm:ss.fffZ)
      if let date = try? Date(
          stringValue,
          strategy: .iso8601.year().month().day().dateSeparator(.dash).time(includingFractionalSeconds: true)
      ) {
          return date
      }

      // then try decoding date time format (yyyy-MM-ddTHH:mm:ssZ)
      if let date = try? Date(stringValue, strategy: .iso8601) {
          return date
      }

      // then try decoding date only format (yyyy-MM-dd)
      if let date = try? Date(stringValue, strategy: .iso8601.year().month().day().dateSeparator(.dash)) {
          return date
      }

      throw DecodingError.dataCorruptedError(
          in: container,
          debugDescription: "Expected date string to be ISO8601-formatted."
      )
  }
  """
