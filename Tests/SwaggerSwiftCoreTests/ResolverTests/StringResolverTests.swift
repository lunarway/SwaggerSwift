import XCTest

@testable import SwaggerSwiftCore

class StringResolverTests: XCTestCase {
  func testEnumResolvesToEnum() {
    let type = StringResolver.resolve(
      format: nil,
      enumValues: ["value1", "value2"],
      typeNamePrefix: "namePrefix",
      defaultValue: nil,
      serviceName: "")
    if case .enumeration(let typeName) = type {
      XCTAssertEqual(typeName, "NamePrefix")
    } else {
      XCTFail()
    }
  }

  func testStringResolvesToString() {
    let type = StringResolver.resolve(
      format: nil,
      enumValues: nil,
      typeNamePrefix: "",
      defaultValue: nil,
      serviceName: "")
    if case .string = type {
      XCTAssertTrue(true)
    } else {
      XCTFail()
    }
  }

  func testStringFormatResolvesToString() {
    let type = StringResolver.resolve(
      format: .string,
      enumValues: nil,
      typeNamePrefix: "",
      defaultValue: nil,
      serviceName: "")
    if case .string = type {
      XCTAssertTrue(true)
    } else {
      XCTFail()
    }
  }

  func testDateFormatResolvesToObjectDate() {
    let type = StringResolver.resolve(
      format: .date,
      enumValues: nil,
      typeNamePrefix: "",
      defaultValue: nil,
      serviceName: "")
    if case .object(let typeName) = type {
      XCTAssertEqual(typeName, "Date")
    } else {
      XCTFail()
    }
  }

  func testDateTimeFormatResolvesToObjectDate() {
    let type = StringResolver.resolve(
      format: .dateTime,
      enumValues: nil,
      typeNamePrefix: "",
      defaultValue: nil,
      serviceName: "")
    if case .object(let typeName) = type {
      XCTAssertEqual(typeName, "Date")
    } else {
      XCTFail()
    }
  }

  func testPasswordFormatResolvesToString() {
    let type = StringResolver.resolve(
      format: .password,
      enumValues: nil,
      typeNamePrefix: "",
      defaultValue: nil,
      serviceName: "")
    if case .string = type {
      XCTAssertTrue(true)
    } else {
      XCTFail()
    }
  }

  func testEmailFormatResolvesToString() {
    let type = StringResolver.resolve(
      format: .email,
      enumValues: nil,
      typeNamePrefix: "",
      defaultValue: nil,
      serviceName: "")
    if case .string = type {
      XCTAssertTrue(true)
    } else {
      XCTFail()
    }
  }

  func testBinaryFormatResolvesToObjectData() {
    let type = StringResolver.resolve(
      format: .binary,
      enumValues: nil,
      typeNamePrefix: "",
      defaultValue: nil,
      serviceName: "")
    if case .object(let typeName) = type {
      XCTAssertEqual(typeName, "Data")
    } else {
      XCTFail()
    }
  }

  func testLongFormatResolvesToObjectString() {
    let type = StringResolver.resolve(
      format: .long,
      enumValues: nil,
      typeNamePrefix: "",
      defaultValue: nil,
      serviceName: "")
    if case .object(let typeName) = type {
      XCTAssertEqual(typeName, "String")
    } else {
      XCTFail()
    }
  }

  func testFloatFormatResolvesToObjectString() {
    let type = StringResolver.resolve(
      format: .float,
      enumValues: nil,
      typeNamePrefix: "",
      defaultValue: nil,
      serviceName: "")
    if case .object(let typeName) = type {
      XCTAssertEqual(typeName, "String")
    } else {
      XCTFail()
    }
  }

  func testDoubleFormatResolvesToObjectString() {
    let type = StringResolver.resolve(
      format: .double,
      enumValues: nil,
      typeNamePrefix: "",
      defaultValue: nil,
      serviceName: "")
    if case .object(let typeName) = type {
      XCTAssertEqual(typeName, "String")
    } else {
      XCTFail()
    }
  }

  func testByteFormatResolvesToObjectString() {
    let type = StringResolver.resolve(
      format: .byte,
      enumValues: nil,
      typeNamePrefix: "",
      defaultValue: nil,
      serviceName: "")
    if case .object(let typeName) = type {
      XCTAssertEqual(typeName, "String")
    } else {
      XCTFail()
    }
  }

  func testBooleanFormatResolvesToObjectString() {
    let type = StringResolver.resolve(
      format: .boolean,
      enumValues: nil,
      typeNamePrefix: "",
      defaultValue: nil,
      serviceName: "")
    if case .object(let typeName) = type {
      XCTAssertEqual(typeName, "String")
    } else {
      XCTFail()
    }
  }

  func testInt32FormatResolvesToObjectString() {
    let type = StringResolver.resolve(
      format: .int32,
      enumValues: nil,
      typeNamePrefix: "",
      defaultValue: nil,
      serviceName: "")
    if case .object(let typeName) = type {
      XCTAssertEqual(typeName, "String")
    } else {
      XCTFail()
    }
  }

  func testUnsupportedISO8601ResolvesToDate() {
    let type = StringResolver.resolve(
      format: .unsupported("ISO8601"),
      enumValues: nil,
      typeNamePrefix: "",
      defaultValue: nil,
      serviceName: "")
    if case .date = type {
      XCTAssertTrue(true)
    } else {
      XCTFail()
    }
  }

  func testUnsupportedUUIDResolvesToObjectString() {
    let type = StringResolver.resolve(
      format: .unsupported("uuid"),
      enumValues: nil,
      typeNamePrefix: "",
      defaultValue: nil,
      serviceName: "")
    if case .object(let typeName) = type {
      XCTAssertEqual(typeName, "String")
    } else {
      XCTFail()
    }
  }

  func testUnsupportedDateTimeResolvesToObjectDate() {
    let type = StringResolver.resolve(
      format: .unsupported("datetime"),
      enumValues: nil,
      typeNamePrefix: "",
      defaultValue: nil,
      serviceName: "")
    if case .object(let typeName) = type {
      XCTAssertEqual(typeName, "Date")
    } else {
      XCTFail()
    }
  }

  func testUnsupportedURIResolvesToObjectURL() {
    let type = StringResolver.resolve(
      format: .unsupported("uri"),
      enumValues: nil,
      typeNamePrefix: "",
      defaultValue: nil,
      serviceName: "")
    if case .object(let typeName) = type {
      XCTAssertEqual(typeName, "URL")
    } else {
      XCTFail()
    }
  }

  func testUnsupportedResolvesToTypealias() {
    let type = StringResolver.resolve(
      format: .unsupported("randomString"),
      enumValues: nil,
      typeNamePrefix: "namePrefix",
      defaultValue: nil,
      serviceName: "")
    if case .typeAlias(let typeName, let type) = type,
      case .string = type
    {
      XCTAssertEqual(typeName, "namePrefix")
    } else {
      XCTFail()
    }
  }
}
