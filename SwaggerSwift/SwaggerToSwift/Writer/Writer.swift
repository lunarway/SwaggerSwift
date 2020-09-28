import Foundation

private func write(text: String, to path: String) throws {
    let defaultHeader = "// Autogenerated by Swagger Parser\n// Any custom changes to these files are not recommended."

    let fileData = "\(defaultHeader)\n\n\(text)".data(using: .utf8)

    if !FileManager.default.createFile(atPath: path, contents: fileData, attributes: nil) {
        throw NSError(domain: "SwaggerParser", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to create file at: \(path)"])
    }

    print("Wrote: \(path)")
}

//func writeProjectToDisk(path: String, projectTitle: String, definitions: [Printable], apiClass: SwiftStruct) {
//    let fileManager = FileManager.default
//
//    let projectRootPath = "\(path)/\(projectTitle)"
//    let sourceDirectory = "\(projectRootPath)/Sources/\(projectTitle)"
//
//    try! fileManager.createDirectory(atPath: "\(sourceDirectory)/Models",
//                                     withIntermediateDirectories: true,
//                                     attributes: nil)
//
//    definitions.forEach { type in
//        let filePath = "\(sourceDirectory)/Models/\(type.type).swift"
//        try! write(text: type.print(), to: filePath)
//    }
//
//    let swiftPackageFile = """
//// swift-tools-version:5.3
//// The swift-tools-version declares the minimum version of Swift required to build this package.
//
//import PackageDescription
//
//let package = Package(
//    name: "PACKAGE_NAME",
//    products: [
//        .library(
//            name: "PACKAGE_NAME",
//            targets: ["PACKAGE_NAME"]),
//    ],
//    targets: [
//        .target(
//            name: "PACKAGE_NAME",
//            dependencies: [],
//            resources: nil)
//    ]
//)
//
//""".replacingOccurrences(of: "PACKAGE_NAME", with: projectTitle)
//
//    FileManager.default.createFile(atPath: "\(projectRootPath)/Package.swift", contents: swiftPackageFile.data(using: .utf8), attributes: nil)
//    try! write(text: apiClass.description, to: "\(sourceDirectory)/\(apiClass.typeName).swift")
//}
