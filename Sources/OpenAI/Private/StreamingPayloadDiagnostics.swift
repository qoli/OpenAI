import Foundation

enum StreamingPayloadDiagnostics {
    static func describe(jsonContent: String, urlRequest: URLRequest) -> String {
        let requestSummary = "\(urlRequest.httpMethod ?? "REQUEST") \(urlRequest.url?.absoluteString ?? "unknown")"
        let payload = payloadSummary(for: jsonContent)

        guard let jsonData = jsonContent.data(using: .utf8) else {
            return "Streaming payload structure: request=\(requestSummary), utf8=invalid, \(payload)"
        }

        do {
            let jsonObject = try JSONSerialization.jsonObject(with: jsonData)

            if let dictionary = jsonObject as? [String: Any] {
                let keys = dictionary.keys.sorted().joined(separator: ", ")
                if let errorPayload = dictionary["error"] as? [String: Any] {
                    let errorKeys = errorPayload.keys.sorted().joined(separator: ", ")
                    return
                        "Streaming payload structure: request=\(requestSummary), topLevel=object, keys=[\(keys)], errorKeys=[\(errorKeys)], \(payload)"
                }

                return
                    "Streaming payload structure: request=\(requestSummary), topLevel=object, keys=[\(keys)], \(payload)"
            }

            if let array = jsonObject as? [Any] {
                return
                    "Streaming payload structure: request=\(requestSummary), topLevel=array, count=\(array.count), \(payload)"
            }

            return
                "Streaming payload structure: request=\(requestSummary), topLevel=\(String(describing: type(of: jsonObject))), \(payload)"
        } catch {
            return
                "Streaming payload structure: request=\(requestSummary), json=invalid, \(payload)"
        }
    }

    static func payloadSummary(for jsonContent: String, maxLength: Int = 2000) -> String {
        let normalized =
            jsonContent
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")

        guard normalized.count > maxLength else {
            return "rawPayload=\(normalized)"
        }

        let endIndex = normalized.index(normalized.startIndex, offsetBy: maxLength)
        return "payloadPreview=\(normalized[..<endIndex])…, payloadLength=\(normalized.count), truncated=true"
    }
}
