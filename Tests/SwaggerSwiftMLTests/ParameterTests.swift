import XCTest
import Yams

@testable import SwaggerSwiftML

final class ParameterTests: XCTestCase {
    static var fileContents: String!
    override class func setUp() {
        let basicFileUrl = Bundle.module.url(forResource: "BasicSwagger", withExtension: "yaml")

        fileContents = try! String(contentsOf: basicFileUrl!, encoding: .utf8)
    }

    func testParseArrayParameter() {
        let basicFileUrl = Bundle.module.url(
            forResource: "Parameter/parameter_array",
            withExtension: "yaml"
        )

        let fileContents = try! String(contentsOf: basicFileUrl!, encoding: .utf8)

        let parameter = try! YAMLDecoder().decode(Parameter.self, from: fileContents)

        XCTAssertEqual(parameter.name, "user")

        XCTAssertEqual(parameter.description, "user to add to the system")
        XCTAssertEqual(parameter.required, true)
    }

    func testRequiredDefaultsToFalse() {
        let basicFileUrl = Bundle.module.url(
            forResource: "Parameter/not_defined_required",
            withExtension: "yaml"
        )

        let fileContents = try! String(contentsOf: basicFileUrl!, encoding: .utf8)

        let parameter = try! YAMLDecoder().decode(Parameter.self, from: fileContents)

        XCTAssertEqual(parameter.required, false)
    }

    func testLoadSimpleStringType() {
        let basicFileUrl = Bundle.module.url(
            forResource: "Parameter/string_parameter",
            withExtension: "yaml"
        )

        let fileContents = try! String(contentsOf: basicFileUrl!, encoding: .utf8)

        _ = try! YAMLDecoder().decode(Parameter.self, from: fileContents)

        //        XCTAssertEqual(parameter.type, .string)
    }

    func testBodyLocationHasSchema() {
        let basicFileUrl = Bundle.module.url(
            forResource: "Parameter/parameter_array",
            withExtension: "yaml"
        )

        let fileContents = try! String(contentsOf: basicFileUrl!, encoding: .utf8)

        _ = try! YAMLDecoder().decode(Parameter.self, from: fileContents)

        //        XCTAssertEqual(parameter.location, .body)
    }

    func testFormDataLocation() {
        let basicFileUrl = Bundle.module.url(
            forResource: "Parameter/formdata_param",
            withExtension: "yaml"
        )

        let fileContents = try! String(contentsOf: basicFileUrl!, encoding: .utf8)

        _ = try! YAMLDecoder().decode(Parameter.self, from: fileContents)

        //        XCTAssertEqual(parameter.location, .body)
    }

    func testArrayWithRef() {
        let basicFileUrl = Bundle.module.url(
            forResource: "Parameter/array_with_ref",
            withExtension: "yaml"
        )

        let fileContents = try! String(contentsOf: basicFileUrl!, encoding: .utf8)

        _ = try! YAMLDecoder().decode(Parameter.self, from: fileContents)

        //        XCTAssertEqual(parameter.location, .body)
    }
}
