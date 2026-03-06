import XCTest
@testable import OpenAI

final class RequestPayloadDiagnosticsTests: XCTestCase {
    func testDescribeRedactsAuthorizationAndShowsRawBody() {
        var request = URLRequest(url: URL(string: "https://example.com/v1/chat/completions")!)
        request.httpMethod = "POST"
        request.setValue("Bearer secret-token", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = #"{"model":"test-model","messages":[{"role":"user","content":"Hi"}]}"#.data(using: .utf8)

        let lines = RequestPayloadDiagnostics.describe(request, chunkSize: 4000)
        let combined = lines.joined(separator: "\n")

        XCTAssertTrue(combined.contains("Authorization=Bearer <redacted>"))
        XCTAssertTrue(combined.contains(#"rawBody: {"model":"test-model","messages":[{"role":"user","content":"Hi"}]}"#))
    }

    func testDescribeSummarizesImageDataURL() {
        var request = URLRequest(url: URL(string: "https://example.com/v1/chat/completions")!)
        request.httpMethod = "POST"
        request.httpBody = #"""
        {"model":"test-model","messages":[{"role":"user","content":[{"type":"text","text":"describe this"},{"type":"image_url","image_url":{"url":"data:image/jpeg;base64,abcd1234"}}]}]}
        """#.data(using: .utf8)

        let lines = RequestPayloadDiagnostics.describe(request, chunkSize: 4000)
        let combined = lines.joined(separator: "\n")

        XCTAssertTrue(combined.contains("messageCount=1"))
        XCTAssertTrue(combined.contains("imageParts=m0.c1=data-url"))
        XCTAssertTrue(combined.contains("prefix=data:image/jpeg;base64,abcd1234"))
    }
}
