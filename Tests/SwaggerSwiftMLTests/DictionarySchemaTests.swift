import Foundation
import XCTest
import Yams

@testable import SwaggerSwiftML

class DictionarySchemaTests: XCTestCase {
    private func load_schema(path: String) -> Schema {
        let basicFileUrl = Bundle.module.url(forResource: path, withExtension: "yaml")

        let fileContents = try! String(contentsOf: basicFileUrl!, encoding: .utf8)

        return try! YAMLDecoder().decode(Schema.self, from: fileContents)
    }

    func testParseStringToStringDictionary() {
        let schema = load_schema(path: "Schemas/Dictionary/simple_dictionary")
        if case SchemaType.dictionary(valueType: let valueType, _) = schema.type {
            if case DictionaryValueType.schema(let schema) = valueType {
                if case SchemaType.string = schema.type {
                    XCTAssert(true)
                    return
                }
            }
        }

        XCTAssert(false)
    }

    func testParseRequiredKeysDictionary() {
        let schema = load_schema(path: "Schemas/Dictionary/dict_fixed_keys")

        // verify that the value type is a string
        if case SchemaType.dictionary(valueType: let valueType, _) = schema.type {
            if case DictionaryValueType.schema(let schema) = valueType {
                if case SchemaType.string = schema.type {
                    XCTAssert(true)
                } else {
                    XCTAssert(false)
                }
            } else {
                XCTAssert(false)
            }
        } else {
            XCTAssert(false)
        }

        if case SchemaType.dictionary(_, let requiredKeys) = schema.type {
            XCTAssertEqual(requiredKeys.count, 1)
            if requiredKeys.count == 0 {
                XCTAssert(false, "Failed to find any required keys")
                return
            }

            let key = requiredKeys[0]
            XCTAssertEqual(key.name, "default")
            XCTAssertNotNil(key.type)
            XCTAssertTrue(key.required)
        } else {
            XCTAssert(false)
        }
    }

    func testParseValueIsInlineObjectDictionary() {
        let schema = load_schema(path: "Schemas/Dictionary/dict_value_is_inline_schema")

        // verify that the value type is a string
        if case SchemaType.dictionary(valueType: let valueType, _) = schema.type {
            if case DictionaryValueType.schema(let schema) = valueType {
                if case SchemaType.object(properties: let props, _) = schema.type {
                    let codeProp = props["code"]!.unwrapped!

                    if case SchemaType.integer = codeProp.type {
                        XCTAssert(true)
                    } else {
                        XCTAssert(false)
                    }

                    let textProp = props["text"]!.unwrapped!

                    if case SchemaType.string = textProp.type {
                        XCTAssert(true)
                    } else {
                        XCTAssert(false)
                    }
                }
                XCTAssert(true)
            } else {
                XCTAssert(false)
            }
        } else {
            XCTAssert(false)
        }
    }

    func testParseValueIsInlineReferenceDictionary() {
        let schema = load_schema(path: "Schemas/Dictionary/dict_value_is_reference")

        // verify that the value type is a string
        if case SchemaType.dictionary(valueType: let valueType, _) = schema.type {
            if case DictionaryValueType.reference(let ref) = valueType {
                XCTAssertEqual(ref, "#/components/schemas/Message")
            } else {
                XCTAssert(false)
            }
        } else {
            XCTAssert(false)
        }
    }
}

extension SwaggerSwiftML.Node {
    var unwrapped: T? {
        switch self {
        case .node(let node): return node
        case .reference: return nil
        }
    }
}
