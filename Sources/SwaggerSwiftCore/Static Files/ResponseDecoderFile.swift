let responseDecoder = """
    import Foundation

    <ACCESSCONTROL> struct ResponseDecoder {
        private let decoder: JSONDecoder
        
        init() {
            self.decoder = JSONDecoder()
            self.decoder.dateDecodingStrategy = .custom(dateDecodingStrategy)
        }
        
        func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
            return try decoder.decode(type, from: data)
        }
        
        func decodeIfPresent<T: Decodable>(_ type: T.Type, from data: Data) throws -> T? {
            return try decoder.decodeIfPresent(type, from: data)
        }
    }
    """
