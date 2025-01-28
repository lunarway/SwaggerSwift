import XCTest

@testable import SwaggerSwiftCore

class NumberResolverTests: XCTestCase {
  func testNumberResolvesToDouble() throws {
    let type = NumberResolver.resolve(format: nil, defaultValue: nil, serviceName: "123")

    if case .double = type {
      XCTAssertTrue(true)
    } else {
      XCTFail()
    }
  }

  func testLongFormatResolvesToDouble() throws {
    let type = NumberResolver.resolve(format: .long, defaultValue: nil, serviceName: "123")

    if case .double = type {
      XCTAssertTrue(true)
    } else {
      XCTFail()
    }
  }

  func testFloatFormatResolvesToFloat() throws {
    let type = NumberResolver.resolve(format: .float, defaultValue: nil, serviceName: "123")

    if case .float = type {
      XCTAssertTrue(true)
    } else {
      XCTFail()
    }
  }

  func testInt32FormatResolvesToInt() throws {
    let type = NumberResolver.resolve(format: .int32, defaultValue: nil, serviceName: "123")

    if case .int = type {
      XCTAssertTrue(true)
    } else {
      XCTFail()
    }
  }

  func testDoubleFormatResolvesToDouble() throws {
    let type = NumberResolver.resolve(format: .double, defaultValue: nil, serviceName: "123")

    if case .double = type {
      XCTAssertTrue(true)
    } else {
      XCTFail()
    }
  }

  func testDateFormatResolvesToDouble() throws {
    let type = NumberResolver.resolve(format: .date, defaultValue: nil, serviceName: "123")

    if case .double = type {
      XCTAssertTrue(true)
    } else {
      XCTFail()
    }
  }

  func testDateTimeFormatResolvesToDouble() throws {
    let type = NumberResolver.resolve(format: .dateTime, defaultValue: nil, serviceName: "123")

    if case .double = type {
      XCTAssertTrue(true)
    } else {
      XCTFail()
    }
  }

  func testPasswordFormatResolvesToDouble() throws {
    let type = NumberResolver.resolve(format: .password, defaultValue: nil, serviceName: "123")

    if case .double = type {
      XCTAssertTrue(true)
    } else {
      XCTFail()
    }
  }

  func testEmailFormatResolvesToDouble() throws {
    let type = NumberResolver.resolve(format: .email, defaultValue: nil, serviceName: "123")

    if case .double = type {
      XCTAssertTrue(true)
    } else {
      XCTFail()
    }
  }

  func testStringFormatResolvesToDouble() throws {
    let type = NumberResolver.resolve(format: .string, defaultValue: nil, serviceName: "123")

    if case .double = type {
      XCTAssertTrue(true)
    } else {
      XCTFail()
    }
  }

  func testByteFormatResolvesToDouble() throws {
    let type = NumberResolver.resolve(format: .byte, defaultValue: nil, serviceName: "123")

    if case .double = type {
      XCTAssertTrue(true)
    } else {
      XCTFail()
    }
  }

  func testBinaryFormatResolvesToDouble() throws {
    let type = NumberResolver.resolve(format: .binary, defaultValue: nil, serviceName: "123")

    if case .double = type {
      XCTAssertTrue(true)
    } else {
      XCTFail()
    }
  }

  func testBooleanFormatResolvesToDouble() throws {
    let type = NumberResolver.resolve(format: .boolean, defaultValue: nil, serviceName: "123")

    if case .double = type {
      XCTAssertTrue(true)
    } else {
      XCTFail()
    }
  }

  func testUnsupportedIntFormatResolvesToInt() throws {
    let type = NumberResolver.resolve(
      format: .unsupported("int"), defaultValue: nil, serviceName: "123")

    if case .int = type {
      XCTAssertTrue(true)
    } else {
      XCTFail()
    }
  }

  func testUnsupportedIntegerFormatResolvesToInt() throws {
    let type = NumberResolver.resolve(
      format: .unsupported("integer"), defaultValue: nil, serviceName: "123")

    if case .int = type {
      XCTAssertTrue(true)
    } else {
      XCTFail()
    }
  }

  func testUnsupportedInt64FormatResolvesToInt64() throws {
    let type = NumberResolver.resolve(
      format: .unsupported("int64"), defaultValue: nil, serviceName: "123")

    if case .int64 = type {
      XCTAssertTrue(true)
    } else {
      XCTFail()
    }
  }

  func testUnsupportedFloat64FormatResolvesToDouble() throws {
    let type = NumberResolver.resolve(
      format: .unsupported("float64"), defaultValue: nil, serviceName: "123")

    if case .double = type {
      XCTAssertTrue(true)
    } else {
      XCTFail()
    }
  }

  func testUnsupportedDecimalFormatResolvesToDouble() throws {
    let type = NumberResolver.resolve(
      format: .unsupported("decimal"), defaultValue: nil, serviceName: "123")

    if case .double = type {
      XCTAssertTrue(true)
    } else {
      XCTFail()
    }
  }

  func testUnsupportedFormatResolvesToDouble() throws {
    let type = NumberResolver.resolve(
      format: .unsupported("myNonExistingFormat"), defaultValue: nil, serviceName: "123")

    if case .double = type {
      XCTAssertTrue(true)
    } else {
      XCTFail()
    }
  }
}
