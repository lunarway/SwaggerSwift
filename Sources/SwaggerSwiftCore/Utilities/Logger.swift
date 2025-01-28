import Foundation

private struct StdOut: TextOutputStream {
  let stdout = FileHandle.standardOutput

  func write(_ string: String) {
    guard let data = string.data(using: .utf8) else {
      fatalError()  // encoding failure: handle as you wish
    }
    stdout.write(data)
  }
}

private struct StdErr: TextOutputStream {
  let stderr = FileHandle.standardError

  func write(_ string: String) {
    guard let data = string.data(using: .utf8) else {
      fatalError()  // encoding failure: handle as you wish
    }
    stderr.write(data)
  }
}

private var stdout = StdOut()
private var stderr = StdErr()

var isVerboseMode = false
func log(_ text: @autoclosure () -> String, error: Bool = false) {
  if error {
    print(text(), to: &stderr)
  } else if isVerboseMode {
    print(text(), to: &stdout)
  }
}
