# SwaggerSwift

Generate a Swift network layer based on that Swagger (OpenAPI 2.0) file your awesome backenders already made.

## Notes
Missing support for:
- Dictionaries (TypeType:133)
- Full support for object hierarchies. Right now inheritance is just resolved by moving fields into the specific implementations and forgetting about the inheritance model.
- Support for deprecation warning in Swagger file
