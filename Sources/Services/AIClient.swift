import Foundation
import CoreGraphics
import CoreImage
import AppKit

protocol AIClient {
    func analyze(image: CGImage, prompt: String?) async throws -> AIAnalysisResponse
}

struct AIAnalysisResponse {
    let state: DetectionResult.AttentionState
    let confidence: Double
    let reason: String?
    let distractionType: DetectionResult.DistractionType?
}

// 支持 JSON 中 confidence 字段既可以是数字也可以是字符串
struct FlexibleDouble: Codable {
    let value: Double

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let doubleValue = try? container.decode(Double.self) {
            value = doubleValue
        } else if let stringValue = try? container.decode(String.self),
                  let parsed = Double(stringValue) {
            value = parsed
        } else {
            value = 0.5
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(value)
    }
}

class OpenAICompatibleClient: AIClient {
    private let config: AIProviderConfig
    private let session: URLSession
    private let jsonDecoder: JSONDecoder

    init(config: AIProviderConfig) {
        self.config = config

        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForRequest = 30
        sessionConfig.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: sessionConfig)

        self.jsonDecoder = JSONDecoder()
    }

    func analyze(image: CGImage, prompt: String?) async throws -> AIAnalysisResponse {
        let url = config.baseURL.appendingPathComponent("chat/completions")

        print("[AIClient] \(config.name) → \(url.absoluteString)")

        let compressedData = try compressImage(image, maxSize: CGSize(width: 512, height: 384))
        let base64Image = compressedData.base64EncodedString()
        let dataURI = "data:image/jpeg;base64,\(base64Image)"

        let content: [[String: Any]] = [
            ["type": "text", "text": prompt ?? config.defaultPrompt],
            ["type": "image_url", "image_url": ["url": dataURI, "detail": "low"]]
        ]

        let requestBody: [String: Any] = [
            "model": config.model,
            "messages": [
                ["role": "system", "content": config.systemPrompt],
                ["role": "user", "content": content]
            ],
            "temperature": 0.1,
            "max_tokens": 200,
            "response_format": ["type": "json_object"]
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        print("[AIClient] ⏳ Sending request...")
        let startTime = Date()

        let (data, response) = try await session.data(for: request)
        let elapsed = Date().timeIntervalSince(startTime)

        print("[AIClient] ✅ Response received (\(String(format: "%.2f", elapsed))s)")

        guard let httpResponse = response as? HTTPURLResponse else {
            print("[AIClient] ❌ 无效的响应类型")
            throw AIError.invalidResponse
        }

        print("[AIClient] HTTP \(httpResponse.statusCode)")

        guard httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown"
            print("[AIClient] ❌ API 错误: \(errorBody)")
            throw AIError.apiError(statusCode: httpResponse.statusCode, message: errorBody)
        }

        return try parseResponse(data)
    }

    private func parseResponse(_ data: Data) throws -> AIAnalysisResponse {
        // 支持 reasoning_content 字段（GLM 等推理模型会返回此字段）
        struct APIResponse: Codable {
            struct Choice: Codable {
                struct Message: Codable {
                    let content: String?
                    let reasoning_content: String?
                }
                let message: Message
                let finish_reason: String?
            }
            let choices: [Choice]
        }

        let apiResponse = try jsonDecoder.decode(APIResponse.self, from: data)
        guard let choice = apiResponse.choices.first else {
            print("[AIClient] ❌ 响应中无 choices")
            throw AIError.invalidResponseFormat
        }

        // 如果 finish_reason 是 length，说明 token 不够，输出被截断
        if choice.finish_reason == "length" {
            print("[AIClient] ⚠️ 响应被截断 (finish_reason=length)，尝试从已有内容中提取")
        }

        let content = choice.message.content ?? ""
        let reasoningContent = choice.message.reasoning_content ?? ""

        print("[AIClient] 📝 AI content: \(content.isEmpty ? "(空)" : content)")
        if !reasoningContent.isEmpty {
            print("[AIClient] 💭 AI reasoning: \(reasoningContent.prefix(200))")
        }

        struct AnalysisContent: Codable {
            let state: String
            let confidence: FlexibleDouble?
            let reason: String?
            let distractionType: String?
        }

        // 优先从 content 解析 JSON
        if !content.isEmpty, let contentData = content.data(using: .utf8) {
            do {
                let analysis = try jsonDecoder.decode(AnalysisContent.self, from: contentData)
                let conf = analysis.confidence?.value ?? 0.5
                print("[AIClient] ✅ 从 content 解析成功: state=\(analysis.state), confidence=\(conf)")
                return AIAnalysisResponse(
                    state: DetectionResult.AttentionState(rawValue: analysis.state) ?? .focused,
                    confidence: conf,
                    reason: analysis.reason,
                    distractionType: analysis.distractionType.flatMap { DetectionResult.DistractionType(rawValue: $0) }
                )
            } catch {
                print("[AIClient] ⚠️ content JSON 解析失败，尝试其他方式")
            }
        }

        // 从 reasoning_content 中提取关键词推断状态
        if !reasoningContent.isEmpty {
            print("[AIClient] 🔄 从 reasoning_content 推断状态...")
            let lowerReasoning = reasoningContent.lowercased()
            if lowerReasoning.contains("distract") || lowerReasoning.contains("分心") || lowerReasoning.contains("不专注") {
                print("[AIClient] ✅ 从推理内容推断: distracted")
                return AIAnalysisResponse(state: .distracted, confidence: 0.7, reason: "Inferred from reasoning: \(reasoningContent.prefix(100))", distractionType: nil)
            } else if lowerReasoning.contains("away") || lowerReasoning.contains("离开") || lowerReasoning.contains("不在") {
                print("[AIClient] ✅ 从推理内容推断: away")
                return AIAnalysisResponse(state: .away, confidence: 0.7, reason: "Inferred from reasoning: \(reasoningContent.prefix(100))", distractionType: nil)
            } else if lowerReasoning.contains("focus") || lowerReasoning.contains("专注") {
                print("[AIClient] ✅ 从推理内容推断: focused")
                return AIAnalysisResponse(state: .focused, confidence: 0.7, reason: "Inferred from reasoning: \(reasoningContent.prefix(100))", distractionType: nil)
            }
        }

        // 尝试从 content 或整个文本中提取 JSON 片段
        let allText = content + reasoningContent
        if let jsonRange = allText.range(of: "\\{[^}]+\\}", options: .regularExpression) {
            let jsonStr = String(allText[jsonRange])
            if let jsonData = jsonStr.data(using: .utf8) {
                do {
                    let analysis = try jsonDecoder.decode(AnalysisContent.self, from: jsonData)
                    print("[AIClient] ✅ 从文本中提取 JSON 成功: state=\(analysis.state)")
                    let conf = analysis.confidence?.value ?? 0.5
                    return AIAnalysisResponse(
                        state: DetectionResult.AttentionState(rawValue: analysis.state) ?? .focused,
                        confidence: conf,
                        reason: analysis.reason,
                        distractionType: analysis.distractionType.flatMap { DetectionResult.DistractionType(rawValue: $0) }
                    )
                } catch {
                    print("[AIClient] ⚠️ 提取的 JSON 解析失败: \(jsonStr)")
                }
            }
        }

        print("[AIClient] ❌ 所有解析方式均失败")
        throw AIError.invalidResponseFormat
    }
}

// Ollama 原生 API 客户端（/api/chat 端点）
class OllamaClient: AIClient {
    private let config: AIProviderConfig
    private let session: URLSession
    private let jsonDecoder: JSONDecoder

    init(config: AIProviderConfig) {
        self.config = config

        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForRequest = 60
        sessionConfig.timeoutIntervalForResource = 120
        self.session = URLSession(configuration: sessionConfig)

        self.jsonDecoder = JSONDecoder()
    }

    func analyze(image: CGImage, prompt: String?) async throws -> AIAnalysisResponse {
        let url = config.baseURL.appendingPathComponent("api/chat")
        print("[OllamaClient] \(config.model) → \(url.absoluteString)")

        let compressedData = try compressImage(image, maxSize: CGSize(width: 512, height: 384))
        let base64Image = compressedData.base64EncodedString()

        // Ollama 原生格式：images 数组直接传 base64（不需要 data URI 前缀）
        let requestBody: [String: Any] = [
            "model": config.model,
            "messages": [
                ["role": "system", "content": config.systemPrompt],
                ["role": "user", "content": prompt ?? config.defaultPrompt, "images": [base64Image]]
            ],
            "stream": false,
            "format": "json"
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        print("[OllamaClient] ⏳ Sending request...")
        let startTime = Date()

        let (data, response) = try await session.data(for: request)
        let elapsed = Date().timeIntervalSince(startTime)

        print("[OllamaClient] ✅ Response received (\(String(format: "%.2f", elapsed))s)")

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIError.invalidResponse
        }

        print("[OllamaClient] HTTP \(httpResponse.statusCode)")

        guard httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown"
            print("[OllamaClient] ❌ API Error: \(errorBody.prefix(200))")
            throw AIError.apiError(statusCode: httpResponse.statusCode, message: errorBody)
        }

        return try parseOllamaResponse(data)
    }

    private func parseOllamaResponse(_ data: Data) throws -> AIAnalysisResponse {
        // Ollama 原生响应格式
        struct OllamaResponse: Codable {
            struct Message: Codable {
                let role: String
                let content: String
            }
            let model: String?
            let message: Message
            let done: Bool?
        }

        let ollamaResponse = try jsonDecoder.decode(OllamaResponse.self, from: data)
        let content = ollamaResponse.message.content

        print("[OllamaClient] 📝 AI 回复: \(content)")

        guard !content.isEmpty, let contentData = content.data(using: .utf8) else {
            print("[OllamaClient] ❌ 响应内容为空")
            throw AIError.invalidResponseFormat
        }

        struct AnalysisContent: Codable {
            let state: String
            let confidence: FlexibleDouble?
            let reason: String?
            let distractionType: String?
        }

        // 尝试直接解析 JSON
        do {
            let analysis = try jsonDecoder.decode(AnalysisContent.self, from: contentData)
            let conf = analysis.confidence?.value ?? 0.5
            print("[OllamaClient] ✅ 解析成功: state=\(analysis.state), confidence=\(conf)")
            return AIAnalysisResponse(
                state: DetectionResult.AttentionState(rawValue: analysis.state) ?? .focused,
                confidence: conf,
                reason: analysis.reason,
                distractionType: analysis.distractionType.flatMap { DetectionResult.DistractionType(rawValue: $0) }
            )
        } catch {
            print("[OllamaClient] ⚠️ JSON 解析失败，尝试从文本提取: \(error)")
        }

        // 尝试从文本中提取 JSON 片段
        if let jsonRange = content.range(of: "\\{[^}]+\\}", options: .regularExpression) {
            let jsonStr = String(content[jsonRange])
            if let jsonData = jsonStr.data(using: .utf8) {
                do {
                    let analysis = try jsonDecoder.decode(AnalysisContent.self, from: jsonData)
                    let conf = analysis.confidence?.value ?? 0.5
                    print("[OllamaClient] ✅ 从文本提取 JSON 成功: state=\(analysis.state)")
                    return AIAnalysisResponse(
                        state: DetectionResult.AttentionState(rawValue: analysis.state) ?? .focused,
                        confidence: conf,
                        reason: analysis.reason,
                        distractionType: analysis.distractionType.flatMap { DetectionResult.DistractionType(rawValue: $0) }
                    )
                } catch {
                    print("[OllamaClient] ⚠️ 提取的 JSON 也无法解析")
                }
            }
        }

        // 最后尝试关键词推断
        let lower = content.lowercased()
        if lower.contains("distract") || lower.contains("分心") {
            return AIAnalysisResponse(state: .distracted, confidence: 0.6, reason: content, distractionType: nil)
        } else if lower.contains("away") || lower.contains("离开") {
            return AIAnalysisResponse(state: .away, confidence: 0.6, reason: content, distractionType: nil)
        }

        // 默认假设专注
        return AIAnalysisResponse(state: .focused, confidence: 0.5, reason: content, distractionType: nil)
    }
}

struct AIProviderConfig {
    let name: String
    let baseURL: URL
    let model: String
    let apiKey: String
    let systemPrompt: String
    let defaultPrompt: String
}

class AIClientFactory {
    static func createClient(baseURL: String, model: String, apiKey: String, name: String) -> AIClient {
        guard let url = URL(string: baseURL) else {
            fatalError("无效的 URL: \(baseURL)")
        }

        let config = AIProviderConfig(
            name: name,
            baseURL: url,
            model: model,
            apiKey: apiKey,
            systemPrompt: "You are a focus detection assistant. The camera is the built-in webcam of a Mac laptop, facing the user. Determine if the user is focused on working at the computer. Return JSON only, no explanation.",
            defaultPrompt: "Analyze the image. The user should be sitting in front of a Mac laptop.\nRules:\n- focused: user faces the screen, eyes looking at monitor, typing or reading\n- distracted: user is looking at phone, eating, chatting with others, looking away from screen for extended time, or doing non-work activities\n- away: no person visible, or person has left the seat\nReturn: {\"state\":\"focused|distracted|away\",\"confidence\":0.0-1.0}"
        )

        // Ollama 使用原生 API 客户端
        if name == "Ollama" {
            print("[AIClientFactory] 🦙 使用 Ollama 原生客户端")
            return OllamaClient(config: config)
        }

        return OpenAICompatibleClient(config: config)
    }
}

func compressImage(_ image: CGImage, maxSize: CGSize) throws -> Data {
    print("[AIClient] 🖼️ 压缩图片: \(image.width)x\(image.height) -> \(Int(maxSize.width))x\(Int(maxSize.height))")

    let ciImage = CIImage(cgImage: image)

    let scale = min(
        maxSize.width / CGFloat(image.width),
        maxSize.height / CGFloat(image.height),
        1.0
    )

    let newSize = CGSize(
        width: CGFloat(image.width) * scale,
        height: CGFloat(image.height) * scale
    )

    let filter = CIFilter(name: "CILanczosScaleTransform")!
    filter.setValue(ciImage, forKey: kCIInputImageKey)
    filter.setValue(scale, forKey: kCIInputScaleKey)

    guard let outputImage = filter.outputImage else {
        throw AIError.invalidResponse
    }

    let context = CIContext(options: [.cacheIntermediates: false])
    guard let cgImage = context.createCGImage(outputImage, from: outputImage.extent) else {
        throw AIError.invalidResponse
    }

    let nsImage = NSImage(cgImage: cgImage, size: newSize)

    guard let tiffData = nsImage.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiffData),
          let jpegData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.5]) else {
        throw AIError.invalidResponse
    }

    print("[AIClient] ✅ 压缩完成: \(jpegData.count) bytes")

    return jpegData
}
