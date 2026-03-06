import XCTest
@testable import OpenAI

final class StreamingPayloadDiagnosticsTests: XCTestCase {
    func testDescribeReportsTopLevelKeys() {
        let request = URLRequest(url: URL(string: "https://example.com/v1/chat/completions")!)
        let payload = #"{"id":"abc","object":"chat.completion.chunk","usage":{"total_tokens":10}}"#

        let description = StreamingPayloadDiagnostics.describe(
            jsonContent: payload,
            urlRequest: request
        )

        XCTAssertTrue(description.contains("topLevel=object"))
        XCTAssertTrue(description.contains("keys=[id, object, usage]"))
        XCTAssertTrue(description.contains("https://example.com/v1/chat/completions"))
        XCTAssertTrue(description.contains(#"rawPayload={"id":"abc","object":"chat.completion.chunk","usage":{"total_tokens":10}}"#))
    }

    func testDescribeReportsErrorKeys() {
        let request = URLRequest(url: URL(string: "https://example.com/v1/chat/completions")!)
        let payload = #"{"error":{"message":"bad request","type":"invalid_request_error"}}"#

        let description = StreamingPayloadDiagnostics.describe(
            jsonContent: payload,
            urlRequest: request
        )

        XCTAssertTrue(description.contains("errorKeys=[message, type]"))
        XCTAssertTrue(description.contains(#"rawPayload={"error":{"message":"bad request","type":"invalid_request_error"}}"#))
    }
}
