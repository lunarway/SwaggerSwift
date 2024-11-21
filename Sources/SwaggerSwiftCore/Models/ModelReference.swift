enum ModelReference {
    case responses(typeName: String)
    case definitions(typeName: String)

    init(rawValue: String) throws {
        guard rawValue.hasPrefix("#/") else {
            throw InvalidReference()
        }

        let reference = rawValue
            .replacingOccurrences(of: "#/", with: "")
            .split(separator: "/")

        guard reference.count == 2 else {
            throw InvalidReference()
        }

        let type = String(reference[0])
        let typeName = String(reference[1])
            .modelNamed
            .split(separator: ".").map { String($0).uppercasingFirst }.joined()

        switch type.lowercased() {
        case "definitions":
            self = .definitions(typeName: typeName)
        case "responses":
            self = .responses(typeName: typeName)
        default:
            throw InvalidReference()
        }
    }

    var typeName: String {
        switch self {
        case .definitions(let typeName): return typeName
        case .responses(let typeName): return typeName
        }
    }
}

struct InvalidReference: Error { }
