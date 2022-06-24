import XCTest
@testable import SwaggerSwiftCore

class IntegerResolverTests: XCTestCase {
    func testIntegerResolvesToInt() throws {
        let type = IntegerResolver.resolve(format: nil)

        if case .int = type {
            XCTAssertTrue(true)
        } else {
            XCTFail()
        }
    }

    func testLongFormatResolvesToDouble() throws {
        let type = IntegerResolver.resolve(format: .long)

        if case .double = type {
            XCTAssertTrue(true)
        } else {
            XCTFail()
        }
    }

    func testFloatFormatResolvesToFloat() throws {
        let type = IntegerResolver.resolve(format: .float)

        if case .float = type {
            XCTAssertTrue(true)
        } else {
            XCTFail()
        }
    }

    func testInt32FormatResolvesToInt() throws {
        let type = IntegerResolver.resolve(format: .int32)

        if case .int = type {
            XCTAssertTrue(true)
        } else {
            XCTFail()
        }
    }

    func testDoubleFormatResolvesToDouble() throws {
        let type = IntegerResolver.resolve(format: .double)

        if case .double = type {
            XCTAssertTrue(true)
        } else {
            XCTFail()
        }
    }

    func testDateFormatResolvesToInt() throws {
        let type = IntegerResolver.resolve(format: .date)

        if case .int = type {
            XCTAssertTrue(true)
        } else {
            XCTFail()
        }
    }

    func testDateTimeFormatResolvesToInt() throws {
        let type = IntegerResolver.resolve(format: .dateTime)

        if case .int = type {
            XCTAssertTrue(true)
        } else {
            XCTFail()
        }
    }

    func testPasswordFormatResolvesToInt() throws {
        let type = IntegerResolver.resolve(format: .password)

        if case .int = type {
            XCTAssertTrue(true)
        } else {
            XCTFail()
        }
    }

    func testEmailFormatResolvesToInt() throws {
        let type = IntegerResolver.resolve(format: .email)

        if case .int = type {
            XCTAssertTrue(true)
        } else {
            XCTFail()
        }
    }

    func testStringFormatResolvesToInt() throws {
        let type = IntegerResolver.resolve(format: .string)

        if case .int = type {
            XCTAssertTrue(true)
        } else {
            XCTFail()
        }
    }

    func testByteFormatResolvesToInt() throws {
        let type = IntegerResolver.resolve(format: .byte)

        if case .int = type {
            XCTAssertTrue(true)
        } else {
            XCTFail()
        }
    }

    func testBinaryFormatResolvesToInt() throws {
        let type = IntegerResolver.resolve(format: .binary)

        if case .int = type {
            XCTAssertTrue(true)
        } else {
            XCTFail()
        }
    }

    func testBooleanFormatResolvesToInt() throws {
        let type = IntegerResolver.resolve(format: .boolean)

        if case .int = type {
            XCTAssertTrue(true)
        } else {
            XCTFail()
        }
    }

    func testUnsupportedIntFormatResolvesToInt() throws {
        let type = IntegerResolver.resolve(format: .unsupported("int"))

        if case .int = type {
            XCTAssertTrue(true)
        } else {
            XCTFail()
        }
    }

    func testUnsupportedInt64FormatResolvesToInt64() throws {
        let type = IntegerResolver.resolve(format: .unsupported("int64"))

        if case .int64 = type {
            XCTAssertTrue(true)
        } else {
            XCTFail()
        }
    }

    func testUnsupportedDecimalFormatResolvesToDouble() throws {
        let type = IntegerResolver.resolve(format: .unsupported("decimal"))

        if case .double = type {
            XCTAssertTrue(true)
        } else {
            XCTFail()
        }
    }

    func testUnsupportedFormatResolvesToInt() throws {
        let type = IntegerResolver.resolve(format: .unsupported("myNonExistingFormat"))

        if case .int = type {
            XCTAssertTrue(true)
        } else {
            XCTFail()
        }
    }
}
