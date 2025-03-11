let formData = """
    import Foundation

    <ACCESSCONTROL> struct FormData: Sendable {
        private let crlf = "\\r\\n"

        /// the data representation of the object
        <ACCESSCONTROL> let data: Data
        /// the mime type for the data, e.g. `image/png`
        <ACCESSCONTROL> let mimeType: String?
        /// a filename representing the input - e.g. `image.png`
        <ACCESSCONTROL> let filename: String?

        /// Creates the data part of a multi part request
        /// - Parameters:
        ///   - data: the piece of data being sent
        ///   - mimeType: the mime type for the data, e.g. `image/png`
        ///   - fileName: a filename representing the input - e.g. `image.png`
        <ACCESSCONTROL> init(data: Data, mimeType: String? = nil, fileName: String? = nil) {
            self.data = data
            self.mimeType = mimeType
            self.filename = fileName
        }

        <ACCESSCONTROL> func toRequestData(named fieldName: String, using boundary: String) -> Data {
            func append(string: String, toData data: inout Data) {
                guard let strData = string.data(using: .utf8) else { return }
                data.append(strData)
            }

            var contentDisposition = "Content-Disposition: form-data; name=\\"\\(fieldName)\\""
            if let filename = filename {
                contentDisposition += "; filename=\\"\\(filename)\\""
            }

            var mutableData = Data()

            append(string: "--\\(boundary)" + crlf, toData: &mutableData)
            append(string: contentDisposition + crlf, toData: &mutableData)
            if let mimeType = mimeType {
                append(string: "Content-Type: \\(mimeType)" + crlf + crlf, toData: &mutableData)
            } else {
                append(string: crlf, toData: &mutableData)
            }

            mutableData.append(data)

            append(string: crlf, toData: &mutableData)

            return mutableData as Data
        }
    }
    """
