/// Provides the implementaion to convert a type into some Swift file representation
protocol Swiftable {
    /// The type of the type 🤪
    var typeName: String { get }

    /// Convert the object into its Swift twin
    func toSwift(swaggerFile: SwaggerFile) -> String
}
