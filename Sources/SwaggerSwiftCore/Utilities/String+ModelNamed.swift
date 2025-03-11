extension String {
    var modelNamed: String {
        self.split(separator: "-").map { String($0).uppercasingFirst }.joined()
            .split(separator: "_").map { String($0).uppercasingFirst }.joined()
            .uppercasingFirst
    }
}
