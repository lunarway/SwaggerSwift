public enum CollectionFormat: String, Codable {
    case csv
    case ssv
    case tsv
    case pipes
    case multi
}

extension CollectionFormat: Equatable {}
