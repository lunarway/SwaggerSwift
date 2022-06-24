import XCTest
@testable import SwaggerSwiftCore

class NumberResolverTests: XCTestCase {
    func testNumberResolvesToDouble() throws {
        let type = NumberResolver.resolve(format: nil)

        if case .double = type {
            XCTAssertTrue(true)
        } else {
            XCTFail()
        }
    }

    func testLongFormatResolvesToDouble() throws {
        let type = NumberResolver.resolve(format: .long)

        if case .double = type {
            XCTAssertTrue(true)
        } else {
            XCTFail()
        }
    }

    func testFloatFormatResolvesToFloat() throws {
        let type = NumberResolver.resolve(format: .float)

        if case .float = type {
            XCTAssertTrue(true)
        } else {
            XCTFail()
        }
    }

    func testInt32FormatResolvesToInt() throws {
        let type = NumberResolver.resolve(format: .int32)

        if case .int = type {
            XCTAssertTrue(true)
        } else {
            XCTFail()
        }
    }

    func testDoubleFormatResolvesToDouble() throws {
        let type = NumberResolver.resolve(format: .double)

        if case .double = type {
            XCTAssertTrue(true)
        } else {
            XCTFail()
        }
    }

    func testDateFormatResolvesToDouble() throws {
        let type = NumberResolver.resolve(format: .date)

        if case .double = type {
            XCTAssertTrue(true)
        } else {
            XCTFail()
        }
    }

    func testDateTimeFormatResolvesToDouble() throws {
        let type = NumberResolver.resolve(format: .dateTime)

        if case .double = type {
            XCTAssertTrue(true)
        } else {
            XCTFail()
        }
    }

    func testPasswordFormatResolvesToDouble() throws {
        let type = NumberResolver.resolve(format: .password)

        if case .double = type {
            XCTAssertTrue(true)
        } else {
            XCTFail()
        }
    }

    func testEmailFormatResolvesToDouble() throws {
        let type = NumberResolver.resolve(format: .email)

        if case .double = type {
            XCTAssertTrue(true)
        } else {
            XCTFail()
        }
    }

    func testStringFormatResolvesToDouble() throws {
        let type = NumberResolver.resolve(format: .string)

        if case .double = type {
            XCTAssertTrue(true)
        } else {
            XCTFail()
        }
    }

    func testByteFormatResolvesToDouble() throws {
        let type = NumberResolver.resolve(format: .byte)

        if case .double = type {
            XCTAssertTrue(true)
        } else {
            XCTFail()
        }
    }

    func testBinaryFormatResolvesToDouble() throws {
        let type = NumberResolver.resolve(format: .binary)

        if case .double = type {
            XCTAssertTrue(true)
        } else {
            XCTFail()
        }
    }

    func testBooleanFormatResolvesToDouble() throws {
        let type = NumberResolver.resolve(format: .boolean)

        if case .double = type {
            XCTAssertTrue(true)
        } else {
            XCTFail()
        }
    }

    func testUnsupportedIntFormatResolvesToInt() throws {
        let type = NumberResolver.resolve(format: .unsupported("int"))

        if case .int = type {
            XCTAssertTrue(true)
        } else {
            XCTFail()
        }
    }

    func testUnsupportedIntegerFormatResolvesToInt() throws {
        let type = NumberResolver.resolve(format: .unsupported("integer"))

        if case .int = type {
            XCTAssertTrue(true)
        } else {
            XCTFail()
        }
    }

    func testUnsupportedInt64FormatResolvesToInt64() throws {
        let type = NumberResolver.resolve(format: .unsupported("int64"))

        if case .int64 = type {
            XCTAssertTrue(true)
        } else {
            XCTFail()
        }
    }

    func testUnsupportedFloat64FormatResolvesToDouble() throws {
        let type = NumberResolver.resolve(format: .unsupported("float64"))

        if case .double = type {
            XCTAssertTrue(true)
        } else {
            XCTFail()
        }
    }

    func testUnsupportedDecimalFormatResolvesToDouble() throws {
        let type = NumberResolver.resolve(format: .unsupported("decimal"))

        if case .double = type {
            XCTAssertTrue(true)
        } else {
            XCTFail()
        }
    }

    func testUnsupportedFormatResolvesToDouble() throws {
        let type = NumberResolver.resolve(format: .unsupported("myNonExistingFormat"))

        if case .double = type {
            XCTAssertTrue(true)
        } else {
            XCTFail()
        }
    }
}
