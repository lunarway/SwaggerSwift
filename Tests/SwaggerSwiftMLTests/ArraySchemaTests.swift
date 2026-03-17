import Foundation
import XCTest
import Yams

@testable import SwaggerSwiftML

class ArraySchemaTests: XCTestCase {
    private func load_schema(path: String) -> Schema {
        let basicFileUrl = Bundle.module.url(forResource: path, withExtension: "yaml")

        let fileContents = try! String(contentsOf: basicFileUrl!, encoding: .utf8)

        return try! YAMLDecoder().decode(Schema.self, from: fileContents)
    }

    func testParseArray() {
        let schema = load_schema(path: "Schemas/arrays/array")
        if case SchemaType.array(
            let
                items,
            collectionFormat: _,
            maxItems: _,
            minItems: _,
            uniqueItems: _
        ) = schema.type {
            XCTAssert(true)
        } else {
            XCTAssert(false)
        }
    }

    func testParseArrayRequired() {
        let schema = load_schema(path: "Schemas/arrays/array")
        if case SchemaType.array(
            let
                items,
            collectionFormat: _,
            maxItems: _,
            minItems: _,
            uniqueItems: _
        ) = schema.type {
            switch items {
            case .node(let items):
                switch items.type {
                case .object(let required, properties: _, allOf: _):
                    XCTAssertEqual(3, required.count)
                default:
                    XCTAssert(false)
                }
            default:
                XCTAssert(false)
            }
        } else {
            XCTAssert(false)
        }
    }

    func testParseComplexObjectWithArrayArrayProperty() {
        _ = load_schema(path: "Schemas/complex_object_with_array_property")
    }
}
