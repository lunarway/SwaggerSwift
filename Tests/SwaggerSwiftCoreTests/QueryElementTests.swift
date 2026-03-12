import SwaggerSwiftML
import XCTest

@testable import SwaggerSwiftCore

final class QueryElementTests: XCTestCase {
    // MARK: - Multi collection format (required)

    func testRequiredArrayMultiNonEnum() {
        let element = QueryElement(
            fieldName: "color",
            fieldValue: "color",
            isOptional: false,
            valueType: .array(isEnum: false, collectionFormat: .multi)
        )

        let result = element.toString()

        XCTAssertEqual(
            result,
            "color.forEach { queryItems.append(URLQueryItem(name: \"color\", value: $0)) }"
        )
    }

    func testRequiredArrayMultiEnum() {
        let element = QueryElement(
            fieldName: "color",
            fieldValue: "color",
            isOptional: false,
            valueType: .array(isEnum: true, collectionFormat: .multi)
        )

        let result = element.toString()

        XCTAssertEqual(
            result,
            "color.forEach { queryItems.append(URLQueryItem(name: \"color\", value: $0.rawValue)) }"
        )
    }

    // MARK: - Multi collection format (optional)

    func testOptionalArrayMultiNonEnum() {
        let element = QueryElement(
            fieldName: "color",
            fieldValue: "color",
            isOptional: true,
            valueType: .array(isEnum: false, collectionFormat: .multi)
        )

        let result = element.toString()

        XCTAssertEqual(
            result,
            """
            if let colorValue = color {
                colorValue.forEach { queryItems.append(URLQueryItem(name: "color", value: $0)) }
            }
            """
        )
    }

    func testOptionalArrayMultiEnum() {
        let element = QueryElement(
            fieldName: "color",
            fieldValue: "color",
            isOptional: true,
            valueType: .array(isEnum: true, collectionFormat: .multi)
        )

        let result = element.toString()

        XCTAssertEqual(
            result,
            """
            if let colorValue = color {
                colorValue.forEach { queryItems.append(URLQueryItem(name: "color", value: $0.rawValue)) }
            }
            """
        )
    }

    // MARK: - CSV collection format (existing behavior)

    func testRequiredArrayCsvEnum() {
        let element = QueryElement(
            fieldName: "color",
            fieldValue: "color",
            isOptional: false,
            valueType: .array(isEnum: true, collectionFormat: .csv)
        )

        let result = element.toString()

        XCTAssertEqual(
            result,
            "queryItems.append(URLQueryItem(name: \"color\", value: color.map { $0.rawValue }.joined(separator: \",\")))"
        )
    }

    func testOptionalArrayCsvEnum() {
        let element = QueryElement(
            fieldName: "color",
            fieldValue: "color",
            isOptional: true,
            valueType: .array(isEnum: true, collectionFormat: .csv)
        )

        let result = element.toString()

        XCTAssertEqual(
            result,
            """
            if let colorValue = color {
                queryItems.append(URLQueryItem(name: "color", value: colorValue.map { $0.rawValue }.joined(separator: ",")))
            }
            """
        )
    }
}
