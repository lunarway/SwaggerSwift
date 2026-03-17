import Foundation
import XCTest
import Yams

@testable import SwaggerSwiftML

class SchemaTests: XCTestCase {
    func testParsePrimitiveSchema() {
        let basicFileUrl = Bundle.module.url(
            forResource: "Schemas/PrimitiveSchema",
            withExtension: "yaml"
        )

        let fileContents = try! String(contentsOf: basicFileUrl!, encoding: .utf8)

        let schema = try! YAMLDecoder().decode(Schema.self, from: fileContents)

        switch schema.type {
        case .string(let format, _, _, _, _, _):
            XCTAssertNotNil(format)
            XCTAssertEqual(format!, .email)
        default:
            XCTAssert(false)
        }
    }

    func testParseSimpleModel() {
        let basicFileUrl = Bundle.module.url(forResource: "Schemas/simple_model", withExtension: "yaml")

        let fileContents = try! String(contentsOf: basicFileUrl!, encoding: .utf8)

        let schema = try! YAMLDecoder().decode(Schema.self, from: fileContents)

        switch schema.type {
        case .object(let properties, _):
            XCTAssertTrue(true)
            let nameProperty = properties["name"]!
            XCTAssertNotNil(nameProperty)
            switch nameProperty {
            case .reference:
                XCTAssert(false, "should not find a reference")
            case .node(let property):
                switch property.type {
                case .string(let format, let enumValues, let maxLength, let minLength, let pattern, _):
                    XCTAssertNil(format)
                    XCTAssertNil(enumValues)
                    XCTAssertNil(maxLength)
                    XCTAssertNil(minLength)
                    XCTAssertNil(pattern)
                default:
                    XCTAssert(false, "Found type: \(property.type)")
                }
            }

            let addressProperty = properties["address"]!
            XCTAssertNotNil(addressProperty)
            switch addressProperty {
            case .reference(let ref):
                XCTAssertEqual(ref, "#/definitions/Address")
            default:
                XCTAssert(false)
            }

            let ageProperty = properties["age"]!
            XCTAssertNotNil(ageProperty)
            switch ageProperty {
            case .reference:
                XCTAssert(false, "should not find a reference")
            case .node(let property):
                switch property.type {
                case .integer(
                    let format,
                    let maximum,
                    let exclusiveMaximum,
                    let minimum,
                    let exclusiveMinimum,
                    let multipleOf,
                    _
                ):
                    XCTAssertNotNil(format)
                    XCTAssertEqual(format!, .int32)
                    XCTAssertEqual(minimum!, 0)
                    XCTAssertNil(maximum)
                    XCTAssertNil(multipleOf)
                    XCTAssertNil(exclusiveMinimum)
                    XCTAssertNil(exclusiveMaximum)
                default:
                    XCTAssert(false, "Found type: \(property.type)")
                }
            }
        default:
            XCTAssert(false)
        }
    }

    // MARK: Date

    func testParseDate() {
        let basicFileUrl = Bundle.module.url(forResource: "Schemas/iso8601_date", withExtension: "yaml")

        let fileContents = try! String(contentsOf: basicFileUrl!, encoding: .utf8)

        _ = try! YAMLDecoder().decode(Schema.self, from: fileContents)

    }

    // MARK: Definitions

    func testParseSimpleDefinition() {
        let basicFileUrl = Bundle.module.url(
            forResource: "Schemas/definition_schema",
            withExtension: "yaml"
        )

        let fileContents = try! String(contentsOf: basicFileUrl!, encoding: .utf8)

        let schema = try! YAMLDecoder().decode(Schema.self, from: fileContents)

        if case SchemaType.object(properties: let properties, _) = schema.type {
            XCTAssertEqual(2, properties.count)
        } else {
            XCTAssert(false, "Wrong type on definition")
        }
    }

    func testParseComplexDefinition() {
        let basicFileUrl = Bundle.module.url(
            forResource: "Schemas/complex_model",
            withExtension: "yaml"
        )

        let fileContents = try! String(contentsOf: basicFileUrl!, encoding: .utf8)

        let schema = try! YAMLDecoder().decode(Schema.self, from: fileContents)

        if case SchemaType.object(properties: let properties, _) = schema.type {
            XCTAssertEqual(4, properties.count)
        } else {
            XCTAssert(false, "Wrong type on definition")
        }
    }

    // MARK: Array

    func testArrayWithObjectReference() {
        let basicFileUrl = Bundle.module.url(
            forResource: "Items/items_object_ref",
            withExtension: "yaml"
        )

        let fileContents = try! String(contentsOf: basicFileUrl!, encoding: .utf8)

        let schema = try! YAMLDecoder().decode(Schema.self, from: fileContents)

        if case SchemaType.array(let node, _, _, _, _) = schema.type {
            switch node {
            case .reference(let ref):
                XCTAssertEqual(ref, "#/definitions/ItemTypes")
            default:
                XCTAssert(false)
            }
        } else {
            XCTAssert(false)
        }
    }

    // MARK: AnyOf

    func testParseAnyOfObjects() {
        let basicFileUrl = Bundle.module.url(
            forResource: "Schemas/allOf/allof_object",
            withExtension: "yaml"
        )

        let fileContents = try! String(contentsOf: basicFileUrl!, encoding: .utf8)

        let schema = try! YAMLDecoder().decode(Schema.self, from: fileContents)

        guard case SchemaType.object(properties: let properties, let allOf) = schema.type else {
            XCTAssert(false)
            return
        }

        XCTAssert(properties.isEmpty)
        XCTAssertEqual(allOf?.count, 2)
    }

    func testCannotParseInvalidAnyOfObjects() {
        let basicFileUrl = Bundle.module.url(
            forResource: "Schemas/allOf/invalid_allof",
            withExtension: "yaml"
        )

        let fileContents = try! String(contentsOf: basicFileUrl!, encoding: .utf8)

        do {
            _ = try YAMLDecoder().decode(Schema.self, from: fileContents)
        } catch {
            XCTAssertTrue(true)
        }
    }
}
