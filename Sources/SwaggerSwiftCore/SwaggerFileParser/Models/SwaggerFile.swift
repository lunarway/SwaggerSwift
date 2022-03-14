struct SwaggerFile: Decodable {
    
    let path: String
    let organisation: String
    let services: [String: Service]
    let globalHeaders: [String]?

    enum CodingKeys: String, CodingKey {
        case path
        case organisation
        case services
        case globalHeaders
    }

    init(path: String, organisation: String, services: [String : Service], globalHeaders: [String]?) {
        self.path = path
        self.organisation = organisation
        self.services = services
        self.globalHeaders = globalHeaders
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.path = try container.decode(String.self, forKey: .path)
        self.organisation = try container.decode(String.self, forKey: .organisation)
        self.services = try container.decode([String: Service].self, forKey: .services)
        self.globalHeaders = try container.decodeIfPresent([String].self, forKey: .globalHeaders)
    }
}
