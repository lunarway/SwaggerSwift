import Foundation

struct RawCodingKeys: CodingKey {
    var intValue: Int?
    var stringValue: String

    init?(intValue: Int) {
        self.intValue = intValue
        self.stringValue = "\(intValue)"
    }
    init?(stringValue: String) { self.stringValue = stringValue }

    static func make(key: String) -> RawCodingKeys {
        return RawCodingKeys(stringValue: key)!
    }
}
