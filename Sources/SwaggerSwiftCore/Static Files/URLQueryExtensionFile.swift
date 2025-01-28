let urlQueryItemExtension = """
  import Foundation

  <ACCESSCONTROL> extension URLQueryItem {
      init(name: String, value: Bool) {
          self.init(name: name, value: value ? "true" : "false")
      }

      init(name: String, value: Int) {
          self.init(name: name, value: String(value))
      }

      init(name: String, value: Int64) {
          self.init(name: name, value: String(value))
      }

      init(name: String, value: Double) {
          self.init(name: name, value: String(value))
      }

      init(name: String, value: Date) {
          self.init(name: name, value: ISO8601DateFormatter().string(from: value))
      }

      init(name: String, value: [String]) {
          self.init(name: name, value: value.joined(separator: ","))
      }
  }
  """
