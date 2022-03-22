extension String {
    func indentLines(_ count: Int) -> String {
        self.split(separator: "\n", omittingEmptySubsequences: false)
            .map {
                if $0.trimmingCharacters(in: .whitespaces).count > 0 {
                    return String(repeating: defaultSpacing, count: count) + $0
                } else {
                    return ""
                }
            }
            .joined(separator: "\n")
    }
}
