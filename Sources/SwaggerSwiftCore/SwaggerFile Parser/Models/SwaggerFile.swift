enum APIAccessControl: String, Codable {
    case `private`
    case `internal`
    case `public`
}

struct SwaggerFile: Decodable {
    let path: String
    let organisation: String
    let services: [String: Service]
    let globalHeaders: [String]
    let createSwiftPackage: Bool
    /// What is the name of the directory the files will be placed in? This is also the name as the project in the Swift Package (if created)
    let projectName: String
    /// Where should the project be created?
    let destination: String
    let accessControl: APIAccessControl

    enum CodingKeys: String, CodingKey {
        case path
        case organisation
        case services
        case globalHeaders
        case accessControl
        case createSwiftPackage
        case projectName
        case destination
    }

    init(
        path: String,
        organisation: String,
        services: [String: Service],
        globalHeaders: [String] = [],
        createSwiftPackage: Bool = true,
        accessControl: APIAccessControl = .public,
        destination: String = "./",
        projectName: String = "Services"
    ) {
        self.path = path
        self.organisation = organisation
        self.services = services
        self.globalHeaders = globalHeaders
        self.accessControl = accessControl
        self.createSwiftPackage = createSwiftPackage
        self.destination = destination
        self.projectName = projectName
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.path = try container.decode(String.self, forKey: .path)
        self.organisation = try container.decode(String.self, forKey: .organisation)
        self.services = try container.decode([String: Service].self, forKey: .services)
        self.globalHeaders = (try container.decodeIfPresent([String].self, forKey: .globalHeaders)) ?? []
        self.accessControl = try container.decodeIfPresent(APIAccessControl.self, forKey: .accessControl) ?? .public
        self.createSwiftPackage = try container.decodeIfPresent(Bool.self, forKey: .createSwiftPackage) ?? true
        self.projectName = try container.decodeIfPresent(String.self, forKey: .projectName) ?? "Services"
        self.destination = try container.decodeIfPresent(String.self, forKey: .destination) ?? "./"
    }

    struct Service: Decodable {
        let branch: String?
        let path: String?
    }
}
