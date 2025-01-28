import XCTest

@testable import SwaggerSwiftCore

class BooleanResolverTests: XCTestCase {
  func testBooleanResolvesToBool() throws {
    let type = BooleanResolver.resolve(with: nil)

    if case .boolean(let defaultValue) = type {
      XCTAssertNil(defaultValue)
    } else {
      XCTFail()
    }
  }

  func testBooleanWithDefaultTrueResolvesToBool() throws {
    let type = BooleanResolver.resolve(with: true)

    if case .boolean(let defaultValue) = type {
      XCTAssertTrue(defaultValue!)
    } else {
      XCTFail()
    }
  }

  func testBooleanWithDefaultFalseResolvesToBool() throws {
    let type = BooleanResolver.resolve(with: false)

    if case .boolean(let defaultValue) = type {
      XCTAssertFalse(defaultValue!)
    } else {
      XCTFail()
    }
  }
}
