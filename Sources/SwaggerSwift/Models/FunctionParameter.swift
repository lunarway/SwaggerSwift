/// describes a single parameter to a function
struct FunctionParameter {
    enum In {
        case body
        case formData
        case headers
        case path
        case query
        case nowhere
    }

    let description: String?
    let name: String
    let typeName: TypeType
    let required: Bool
    let `in`: In
    let isEnum: Bool

    var variableName: String {
        name.variableNameFormatted
    }
}

extension String {
    var variableNameFormatted: String {
        split(separator: ".")
            .map { $0.split(separator: "-") }
            .flatMap { $0 }
            .map { String($0).capitalizingFirstLetter() }
            .joined()
            .camelized
            .lowercasingFirst
    }
}
