//
//  OpenAI.swift
//
//
//  Created by Sergii Kryvoblotskyi on 9/18/22.
//

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// OpenAI主類,實現了OpenAIProtocol協議
final public class OpenAI: OpenAIProtocol {

    // 配置結構,包含了API使用所需的基本設定
    public struct Configuration {
        
        /// OpenAI API令牌。查看 https://platform.openai.com/docs/api-reference/authentication
        public let token: String
        
        /// 可選的OpenAI組織標識符。查看 https://platform.openai.com/docs/api-reference/authentication 
        public let organizationIdentifier: String?
        
        /// API主機。如果使用代理或自己的服務器可設置此屬性。預設為api.openai.com
        public let host: String

        /// 如果在自己的主機上設置了自定義路徑的OpenAI API代理,可設置此屬性。預設為空字符串
        public let basePath: String

        /// API版本。預設為"v1"
        public let apiVersion: String

        // 端口號
        public let port: Int
        // 協議類型(http/https)
        public let scheme: String
        
        /// 預設請求超時時間
        public let timeoutInterval: TimeInterval
        
        // 配置初始化方法
        public init(
            token: String,
            organizationIdentifier: String? = nil,
            host: String = "api.openai.com",
            port: Int = 443,
            scheme: String = "https",
            basePath: String = "",
            apiVersion: String = "v1",
            timeoutInterval: TimeInterval = 900.0
        ) {
            self.token = token
            self.organizationIdentifier = organizationIdentifier
            self.host = host
            self.port = port
            self.scheme = scheme
            self.basePath = basePath
            self.apiVersion = apiVersion
            self.timeoutInterval = timeoutInterval
        }
    }
    
    // URL會話管理
    private let session: URLSessionProtocol
    // 用於管理流式傳輸會話的線程安全數組
    private var streamingSessions = ArrayWithThreadSafety<NSObject>()
    
    // 公開配置屬性
    public let configuration: Configuration

    // 簡便初始化方法,只需提供API令牌
    public convenience init(apiToken: String) {
        self.init(configuration: Configuration(token: apiToken), session: URLSession.shared)
    }
    
    // 使用Configuration初始化
    public convenience init(configuration: Configuration) {
        self.init(configuration: configuration, session: URLSession.shared)
    }

    // 內部初始化方法
    init(configuration: Configuration, session: URLSessionProtocol) {
        self.configuration = configuration
        self.session = session
    }

    // 公開初始化方法,可自定義URLSession
    public convenience init(configuration: Configuration, session: URLSession = URLSession.shared) {
        self.init(configuration: configuration, session: session as URLSessionProtocol)
    }
    
    // MARK: - API方法
    
    // 圖像生成
    public func images(query: ImagesQuery, completion: @escaping (Result<ImagesResult, Error>) -> Void) {
        performRequest(request: JSONRequest<ImagesResult>(body: query, url: buildURL(path: .images)), completion: completion)
    }
    
    // 圖像編輯
    public func imageEdits(query: ImageEditsQuery, completion: @escaping (Result<ImagesResult, Error>) -> Void) {
        performRequest(request: MultipartFormDataRequest<ImagesResult>(body: query, url: buildURL(path: .imageEdits)), completion: completion)
    }
    
    // 圖像變體生成
    public func imageVariations(query: ImageVariationsQuery, completion: @escaping (Result<ImagesResult, Error>) -> Void) {
        performRequest(request: MultipartFormDataRequest<ImagesResult>(body: query, url: buildURL(path: .imageVariations)), completion: completion)
    }
    
    // 文本嵌入
    public func embeddings(query: EmbeddingsQuery, completion: @escaping (Result<EmbeddingsResult, Error>) -> Void) {
        performRequest(request: JSONRequest<EmbeddingsResult>(body: query, url: buildURL(path: .embeddings)), completion: completion)
    }
    
    // 聊天完成
    public func chats(query: ChatQuery, completion: @escaping (Result<ChatResult, Error>) -> Void) {
        performRequest(request: JSONRequest<ChatResult>(body: query, url: buildURL(path: .chats)), completion: completion)
    }
    
    // 聊天流式傳輸
    public func chatsStream(query: ChatQuery, onResult: @escaping (Result<ChatStreamResult, Error>) -> Void, completion: ((Error?) -> Void)?) {
        performStreamingRequest(request: JSONRequest<ChatStreamResult>(body: query.makeStreamable(), url: buildURL(path: .chats)), onResult: onResult, completion: completion)
    }
    
    // 獲取單個模型信息
    public func model(query: ModelQuery, completion: @escaping (Result<ModelResult, Error>) -> Void) {
        performRequest(request: JSONRequest<ModelResult>(url: buildURL(path: .models.withPath(query.model)), method: "GET"), completion: completion)
    }
    
    // 獲取所有可用模型列表
    public func models(completion: @escaping (Result<ModelsResult, Error>) -> Void) {
        performRequest(request: JSONRequest<ModelsResult>(url: buildURL(path: .models), method: "GET"), completion: completion)
    }
    
    // 內容審核
    @available(iOS 13.0, *)
    public func moderations(query: ModerationsQuery, completion: @escaping (Result<ModerationsResult, Error>) -> Void) {
        performRequest(request: JSONRequest<ModerationsResult>(body: query, url: buildURL(path: .moderations)), completion: completion)
    }
    
    // 音頻轉錄
    public func audioTranscriptions(query: AudioTranscriptionQuery, completion: @escaping (Result<AudioTranscriptionResult, Error>) -> Void) {
        performRequest(request: MultipartFormDataRequest<AudioTranscriptionResult>(body: query, url: buildURL(path: .audioTranscriptions)), completion: completion)
    }
    
    // 音頻翻譯
    public func audioTranslations(query: AudioTranslationQuery, completion: @escaping (Result<AudioTranslationResult, Error>) -> Void) {
        performRequest(request: MultipartFormDataRequest<AudioTranslationResult>(body: query, url: buildURL(path: .audioTranslations)), completion: completion)
    }
    
    // 文本轉語音
    public func audioCreateSpeech(query: AudioSpeechQuery, completion: @escaping (Result<AudioSpeechResult, Error>) -> Void) {
        performSpeechRequest(request: JSONRequest<AudioSpeechResult>(body: query, url: buildURL(path: .audioSpeech)), completion: completion)
    }
    
}

// MARK: - 網絡請求處理
extension OpenAI {

    // 執行一般HTTP請求
    func performRequest<ResultType: Codable>(request: any URLRequestBuildable, completion: @escaping (Result<ResultType, Error>) -> Void) {
        do {
            let request = try request.build(token: configuration.token, 
                                             organizationIdentifier: configuration.organizationIdentifier,
                                             timeoutInterval: configuration.timeoutInterval)
            let task = session.dataTask(with: request) { data, _, error in
                if let error = error {
                    return completion(.failure(error))
                }
                guard let data = data else {
                    return completion(.failure(OpenAIError.emptyData))
                }
                let decoder = JSONDecoder()
                do {
                    completion(.success(try decoder.decode(ResultType.self, from: data)))
                } catch {
                    completion(.failure((try? decoder.decode(APIErrorResponse.self, from: data)) ?? error))
                }
            }
            task.resume()
        } catch {
            completion(.failure(error))
        }
    }
    
    // 執行流式傳輸請求
    func performStreamingRequest<ResultType: Codable>(request: any URLRequestBuildable, onResult: @escaping (Result<ResultType, Error>) -> Void, completion: ((Error?) -> Void)?) {
        do {
            let request = try request.build(token: configuration.token, 
                                             organizationIdentifier: configuration.organizationIdentifier,
                                             timeoutInterval: configuration.timeoutInterval)
            let session = StreamingSession<ResultType>(urlRequest: request)
            session.onReceiveContent = {_, object in
                onResult(.success(object))
            }
            session.onProcessingError = {_, error in
                onResult(.failure(error))
            }
            session.onComplete = { [weak self] object, error in
                self?.streamingSessions.removeAll(where: { $0 == object })
                completion?(error)
            }
            session.perform()
            streamingSessions.append(session)
        } catch {
            completion?(error)
        }
    }
    
    // 執行語音相關的請求
    func performSpeechRequest(request: any URLRequestBuildable, completion: @escaping (Result<AudioSpeechResult, Error>) -> Void) {
        do {
            let request = try request.build(token: configuration.token, 
                                             organizationIdentifier: configuration.organizationIdentifier,
                                             timeoutInterval: configuration.timeoutInterval)
            
            let task = session.dataTask(with: request) { data, _, error in
                if let error = error {
                    return completion(.failure(error))
                }
                guard let data = data else {
                    return completion(.failure(OpenAIError.emptyData))
                }
                
                completion(.success(AudioSpeechResult(audio: data)))
            }
            task.resume()
        } catch {
            completion(.failure(error))
        }
    }
}

// MARK: - URL構建
extension OpenAI {
    
    // 構建API請求URL
    func buildURL(path: String) -> URL {
        var components = URLComponents()
        components.scheme = configuration.scheme
        components.host = configuration.host
        components.port = configuration.port
        
        // 使用配置中的apiVersion替換hardcoded的"v1"
        let pathComponents = [configuration.basePath, configuration.apiVersion, path.trimmingCharacters(in: ["/"])]
            .filter { !$0.isEmpty }
            .map { $0.trimmingCharacters(in: ["/"]) }
        
        components.path = "/" + pathComponents.joined(separator: "/")
        
        if let url = components.url {
            return url
        } else {
            // 預期components.url不為nil
            // 如果為nil,返回一個空的文件URL
            // 讓所有請求失敗,但不會在顯式展開時崩潰
            return URL(fileURLWithPath: "")
        }
    }
}

// MARK: - API路徑定義
typealias APIPath = String
extension APIPath {
    
    // 文本嵌入
    static let embeddings = "/embeddings"
    // 聊天對話
    static let chats = "/chat/completions"
    // 模型
    static let models = "/models"
    // 內容審核
    static let moderations = "/moderations"
    
    // 語音相關
    static let audioSpeech = "/audio/speech"
    static let audioTranscriptions = "/audio/transcriptions"
    static let audioTranslations = "/audio/translations"
    
    // 圖像相關
    static let images = "/images/generations"
    static let imageEdits = "/images/edits"
    static let imageVariations = "/images/variations"
    
    // 拼接路徑
    func withPath(_ path: String) -> String {
        self + "/" + path
    }
}
