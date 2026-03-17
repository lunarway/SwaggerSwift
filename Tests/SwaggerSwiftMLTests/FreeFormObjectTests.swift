import Foundation
import XCTest
import Yams

@testable import SwaggerSwiftML

class FreeFormObjectTests: XCTestCase {
    private func load_schema(path: String) -> Schema {
        let basicFileUrl = Bundle.module.url(forResource: path, withExtension: "yaml")

        let fileContents = try! String(contentsOf: basicFileUrl!, encoding: .utf8)

        return try! YAMLDecoder().decode(Schema.self, from: fileContents)
    }

    func testParseFreeformEmptyObject() {
        let schema = load_schema(path: "Schemas/freeform/freeform_empty_object")

        if case SchemaType.freeform = schema.type {
            XCTAssert(true)
        } else {
            XCTAssert(false)
        }
    }

    func testParseFreeformEmptyObjectWithEmptyAdditionalProperties() {
        let schema = load_schema(path: "Schemas/freeform/freeform_empty_object_empty_definition")

        if case SchemaType.freeform = schema.type {
            XCTAssert(true)
        } else {
            XCTAssert(false)
        }
    }

    func testParseFreeformEmptyObjectWithFalseAdditionalProperties() {
        let schema = load_schema(path: "Schemas/freeform/freeform_empty_object_bool")

        if case SchemaType.freeform = schema.type {
            XCTAssert(true)
        } else {
            XCTAssert(false)
        }
    }

    func testParseFreeformEmptyObjectWithTypeObjectInAdditionalProperties() {
        let schema = load_schema(path: "Schemas/freeform/freeform_additional_type_object")

        if case SchemaType.freeform = schema.type {
            XCTAssert(true)
        } else {
            XCTAssert(false)
        }
    }
}
