import SwaggerSwiftML
import Testing

struct DefinitionTest {
    @Test func doesSupportGlobalSchemaReferenceInDefinition() async throws {
        let text = """
            info:
              title: API
              description: Exposes relevant endpoints
              version: 1.0.0
              contact:
                url: "https://swift.app/"

            paths:
                /endpoint:
                    get:
                      responses:
                        200:
                          description: Successful response
                          schema:
                            $ref: '#/definitions/Create'
            definitions:
              Create:
                type: object
                $ref: '#/definitions/Stuff'
              Stuff:
                type: object
                properties:
                  id:
                    type: string
            """

        let swagger = try SwaggerReader.read(text: text)
        let createSchema = swagger.definitions?.first(where: { $0.key == "Create" })?.value

        guard let createSchema else {
            Issue.record("There should be a schema named Create")
            return
        }

        switch createSchema {
        case .reference(let reference):
            #expect(reference == "#/definitions/Stuff")
        case .node(_):
            Issue.record("Create schema should be a reference")
        }
    }
}
