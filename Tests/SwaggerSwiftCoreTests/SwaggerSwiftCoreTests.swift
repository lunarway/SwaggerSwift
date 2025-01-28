import XCTest

@testable import SwaggerSwiftCore

final class SwaggerSwiftTests: XCTestCase {
  func testOptionalURLDecodeFormat() {
    let model = Model(
      description: nil,
      typeName: "Test",
      fields: [
        .init(description: nil, type: .object(typeName: "URL"), name: "url", isRequired: false)
      ],
      inheritsFrom: [],
      isInternalOnly: false,
      embeddedDefinitions: [],
      isCodable: true)

    let result = model.modelDefinition(serviceName: nil, accessControl: .public)

    XCTAssertEqual(
      result,
      """
      public struct Test: Codable, Sendable {
          public let url: URL?

          public init(url: URL? = nil) {
              self.url = url
          }

          public init(from decoder: Decoder) throws {
              let container = try decoder.container(keyedBy: StringCodingKey.self)
              // Allows the backend to return badly formatted urls
              if let urlString = try container.decodeIfPresent(String.self, forKey: "url") {
                  self.url = URL(string: urlString)
              } else {
                  self.url = nil
              }
          }

          public func encode(to encoder: Encoder) throws {
              var container = encoder.container(keyedBy: StringCodingKey.self)
              try container.encodeIfPresent(url, forKey: "url")
          }
      }
      """)
  }

  func testURLDecodeFormat() {
    let model = Model(
      description: nil,
      typeName: "Test",
      fields: [
        .init(description: nil, type: .object(typeName: "URL"), name: "url", isRequired: true)
      ],
      inheritsFrom: [],
      isInternalOnly: false,
      embeddedDefinitions: [],
      isCodable: true)

    let result = model.modelDefinition(serviceName: nil, accessControl: .public)

    XCTAssertEqual(
      result,
      """
      public struct Test: Codable, Sendable {
          public let url: URL

          public init(url: URL) {
              self.url = url
          }

          public init(from decoder: Decoder) throws {
              let container = try decoder.container(keyedBy: StringCodingKey.self)
              self.url = try container.decode(URL.self, forKey: "url")
          }

          public func encode(to encoder: Encoder) throws {
              var container = encoder.container(keyedBy: StringCodingKey.self)
              try container.encode(url, forKey: "url")
          }
      }
      """)
  }

  static var allTests = [
    ("testOptionalURLDecodeFormat", testOptionalURLDecodeFormat),
    ("testURLDecodeFormat", testURLDecodeFormat),
  ]
}
