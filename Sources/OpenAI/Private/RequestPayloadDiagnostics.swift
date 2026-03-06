import Foundation

enum RequestPayloadDiagnostics {
    static func log(_ request: URLRequest) {
        for line in describe(request) {
            print(line)
        }
    }

    static func describe(_ request: URLRequest, chunkSize: Int = 4000) -> [String] {
        let requestLine =
            "➡️ OpenAI request: \(request.httpMethod ?? "REQUEST") \(request.url?.absoluteString ?? "unknown")"

        let headersLine = "↳ headers: \(redactedHeaders(from: request))"

        guard let body = request.httpBody, !body.isEmpty else {
            return [requestLine, headersLine, "↳ body: <empty>"]
        }

        guard let bodyString = String(data: body, encoding: .utf8) else {
            return [
                requestLine,
                headersLine,
                "↳ body: <non-utf8> \(body.count) bytes",
            ]
        }

        var lines: [String] = [
            requestLine,
            headersLine,
            "↳ bodyStructure: \(bodyStructureDescription(bodyString))",
        ]

        let normalized =
            bodyString
            .replacingOccurrences(of: "\r", with: "\\r")

        if normalized.count <= chunkSize {
            lines.append("↳ rawBody: \(normalized)")
            return lines
        }

        lines.append("↳ rawBodyLength: \(normalized.count)")
        var startIndex = normalized.startIndex
        var chunkIndex = 1

        while startIndex < normalized.endIndex {
            let endIndex =
                normalized.index(
                    startIndex,
                    offsetBy: chunkSize,
                    limitedBy: normalized.endIndex
                ) ?? normalized.endIndex
            let chunk = normalized[startIndex..<endIndex]
            lines.append("↳ rawBody[\(chunkIndex)]: \(chunk)")
            startIndex = endIndex
            chunkIndex += 1
        }

        return lines
    }

    private static func redactedHeaders(from request: URLRequest) -> String {
        let headers = request.allHTTPHeaderFields ?? [:]
        let redacted = headers.map { key, value -> (String, String) in
            if key.caseInsensitiveCompare("Authorization") == .orderedSame {
                return (key, redactAuthorization(value))
            }
            return (key, value)
        }
        return redacted
            .map { key, value in "\(key)=\(value)" }
            .sorted()
            .joined(separator: ", ")
    }

    private static func redactAuthorization(_ value: String) -> String {
        guard let lastSpace = value.lastIndex(of: " ") else { return "<redacted>" }
        let prefix = value[..<lastSpace]
        return "\(prefix) <redacted>"
    }

    private static func bodyStructureDescription(_ bodyString: String) -> String {
        guard let data = bodyString.data(using: .utf8) else {
            return "utf8=invalid"
        }

        guard let jsonObject = try? JSONSerialization.jsonObject(with: data) else {
            return "json=invalid"
        }

        if let dictionary = jsonObject as? [String: Any] {
            let keys = dictionary.keys.sorted().joined(separator: ", ")
            let messageCount = (dictionary["messages"] as? [Any])?.count
            let imageSummary = imagePartSummary(from: dictionary["messages"] as? [[String: Any]] ?? [])

            var parts = ["topLevel=object", "keys=[\(keys)]"]
            if let messageCount {
                parts.append("messageCount=\(messageCount)")
            }
            if !imageSummary.isEmpty {
                parts.append("imageParts=\(imageSummary)")
            }
            return parts.joined(separator: ", ")
        }

        if let array = jsonObject as? [Any] {
            return "topLevel=array, count=\(array.count)"
        }

        return "topLevel=\(String(describing: type(of: jsonObject)))"
    }

    private static func imagePartSummary(from messages: [[String: Any]]) -> String {
        var parts: [String] = []

        for (messageIndex, message) in messages.enumerated() {
            guard let content = message["content"] as? [[String: Any]] else { continue }

            for (contentIndex, part) in content.enumerated() {
                guard
                    let type = part["type"] as? String,
                    type == "image_url",
                    let imageURL = part["image_url"] as? [String: Any],
                    let url = imageURL["url"] as? String
                else {
                    continue
                }

                if url.hasPrefix("data:") {
                    let prefix = url.prefix(60)
                    parts.append(
                        "m\(messageIndex).c\(contentIndex)=data-url,len=\(url.count),prefix=\(prefix)…"
                    )
                } else {
                    parts.append("m\(messageIndex).c\(contentIndex)=url=\(url)")
                }
            }
        }

        return parts.joined(separator: "; ")
    }
}
