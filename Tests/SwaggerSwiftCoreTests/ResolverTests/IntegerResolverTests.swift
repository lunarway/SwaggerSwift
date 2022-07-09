import XCTest
@testable import SwaggerSwiftCore

class IntegerResolverTests: XCTestCase {
    func testIntegerResolvesToInt() throws {
        let type = IntegerResolver.resolve(format: nil, defaultValue: nil)

        if case .int = type {
            XCTAssertTrue(true)
        } else {
            XCTFail()
        }
    }

    func testLongFormatResolvesToDouble() throws {
        let type = IntegerResolver.resolve(format: .long, defaultValue: nil)

        if case .double = type {
            XCTAssertTrue(true)
        } else {
            XCTFail()
        }
    }

    func testFloatFormatResolvesToFloat() throws {
        let type = IntegerResolver.resolve(format: .float, defaultValue: nil)

        if case .float = type {
            XCTAssertTrue(true)
        } else {
            XCTFail()
        }
    }

    func testInt32FormatResolvesToInt() throws {
        let type = IntegerResolver.resolve(format: .int32, defaultValue: nil)

        if case .int = type {
            XCTAssertTrue(true)
        } else {
            XCTFail()
        }
    }

    func testDoubleFormatResolvesToDouble() throws {
        let type = IntegerResolver.resolve(format: .double, defaultValue: nil)

        if case .double = type {
            XCTAssertTrue(true)
        } else {
            XCTFail()
        }
    }

    func testDateFormatResolvesToInt() throws {
        let type = IntegerResolver.resolve(format: .date, defaultValue: nil)

        if case .int = type {
            XCTAssertTrue(true)
        } else {
            XCTFail()
        }
    }

    func testDateTimeFormatResolvesToInt() throws {
        let type = IntegerResolver.resolve(format: .dateTime, defaultValue: nil)

        if case .int = type {
            XCTAssertTrue(true)
        } else {
            XCTFail()
        }
    }

    func testPasswordFormatResolvesToInt() throws {
        let type = IntegerResolver.resolve(format: .password, defaultValue: nil)

        if case .int = type {
            XCTAssertTrue(true)
        } else {
            XCTFail()
        }
    }

    func testEmailFormatResolvesToInt() throws {
        let type = IntegerResolver.resolve(format: .email, defaultValue: nil)

        if case .int = type {
            XCTAssertTrue(true)
        } else {
            XCTFail()
        }
    }

    func testStringFormatResolvesToInt() throws {
        let type = IntegerResolver.resolve(format: .string, defaultValue: nil)

        if case .int = type {
            XCTAssertTrue(true)
        } else {
            XCTFail()
        }
    }

    func testByteFormatResolvesToInt() throws {
        let type = IntegerResolver.resolve(format: .byte, defaultValue: nil)

        if case .int = type {
            XCTAssertTrue(true)
        } else {
            XCTFail()
        }
    }

    func testBinaryFormatResolvesToInt() throws {
        let type = IntegerResolver.resolve(format: .binary, defaultValue: nil)

        if case .int = type {
            XCTAssertTrue(true)
        } else {
            XCTFail()
        }
    }

    func testBooleanFormatResolvesToInt() throws {
        let type = IntegerResolver.resolve(format: .boolean, defaultValue: nil)

        if case .int = type {
            XCTAssertTrue(true)
        } else {
            XCTFail()
        }
    }

    func testUnsupportedIntFormatResolvesToInt() throws {
        let type = IntegerResolver.resolve(format: .unsupported("int"), defaultValue: nil)

        if case .int = type {
            XCTAssertTrue(true)
        } else {
            XCTFail()
        }
    }

    func testUnsupportedInt64FormatResolvesToInt64() throws {
        let type = IntegerResolver.resolve(format: .unsupported("int64"), defaultValue: nil)

        if case .int64 = type {
            XCTAssertTrue(true)
        } else {
            XCTFail()
        }
    }

    func testUnsupportedDecimalFormatResolvesToDouble() throws {
        let type = IntegerResolver.resolve(format: .unsupported("decimal"), defaultValue: nil)

        if case .double = type {
            XCTAssertTrue(true)
        } else {
            XCTFail()
        }
    }

    func testUnsupportedFormatResolvesToInt() throws {
        let type = IntegerResolver.resolve(format: .unsupported("myNonExistingFormat"), defaultValue: nil)

        if case .int = type {
            XCTAssertTrue(true)
        } else {
            XCTFail()
        }
    }
}
