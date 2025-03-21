//
//  StreamingSession.swift
//
//
//  Created by Sergii Kryvoblotskyi on 18/04/2023.
//

import Foundation
#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

final class StreamingSession<ResultType: Codable>: NSObject, Identifiable, URLSessionDelegate, URLSessionDataDelegate {
    enum StreamingError: Error {
        case unknownContent
        case emptyContent
    }

    var onReceiveContent: ((StreamingSession, ResultType) -> Void)?
    var onProcessingError: ((StreamingSession, Error) -> Void)?
    var onComplete: ((StreamingSession, Error?) -> Void)?

    private let streamingCompletionMarker = "[DONE]"
    private let urlRequest: URLRequest
    private lazy var urlSession: URLSession = {
        let session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        return session
    }()

    private var previousChunkBuffer = ""

    init(urlRequest: URLRequest) {
        self.urlRequest = urlRequest
    }

    func perform() {
        urlSession
            .dataTask(with: urlRequest)
            .resume()
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        onComplete?(self, error)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        guard let stringContent = String(data: data, encoding: .utf8) else {
            onProcessingError?(self, StreamingError.unknownContent)
            return
        }
        processJSON(from: stringContent)
    }
}

extension StreamingSession {
    private func processJSON(from stringContent: String) {
        if stringContent.isEmpty {
            return
        }

//        print(stringContent)

        let lines = "\(previousChunkBuffer)\(stringContent)"
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: .newlines)

        let jsonObjects = lines
            .filter { $0.hasPrefix("data: ") }
            .map { $0.replacingOccurrences(of: "data: ", with: "") }
            .filter { !$0.isEmpty }

        previousChunkBuffer = ""

        guard jsonObjects.isEmpty == false, jsonObjects.first != streamingCompletionMarker else {
            return
        }
        jsonObjects.enumerated().forEach { index, jsonContent in
            guard jsonContent != streamingCompletionMarker && !jsonContent.isEmpty else {
                return
            }

            guard let jsonData = jsonContent.data(using: .utf8) else {
                print("❌ 錯誤：無法將內容轉換為 UTF-8 數據")
                onProcessingError?(self, StreamingError.unknownContent)
                return
            }

            let decoder = JSONDecoder()
            do {
                let object = try decoder.decode(ResultType.self, from: jsonData)
                onReceiveContent?(self, object)
            } catch {
                print("⚠️ 解碼錯誤：\(error)")

                if let decoded = try? decoder.decode(APIErrorResponse.self, from: jsonData) {
                    onProcessingError?(self, decoded)
                } else if index == jsonObjects.count - 1 {
                    previousChunkBuffer = "data: \(jsonContent)" // Chunk ends in a partial JSON
                } else {
                    onProcessingError?(self, error)
                }
            }
        }
    }
}
