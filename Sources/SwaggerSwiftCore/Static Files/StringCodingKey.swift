let stringCodingKey = """
  <ACCESSCONTROL> struct StringCodingKey: CodingKey, ExpressibleByStringLiteral {
      private let string: String
      private var int: Int?

      <ACCESSCONTROL> var stringValue: String { return string }

      <ACCESSCONTROL> init(string: String) {
          self.string = string
      }

      <ACCESSCONTROL> init?(stringValue: String) {
          self.string = stringValue
      }

      <ACCESSCONTROL> var intValue: Int? { return int }

      <ACCESSCONTROL> init?(intValue: Int) {
          self.string = String(describing: intValue)
          self.int = intValue
      }

      <ACCESSCONTROL> init(stringLiteral value: String) {
          self.string = value
      }
  }
  """
