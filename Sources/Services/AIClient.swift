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

        print("[AIClient] 📡 请求 URL: \(url.absoluteString)")
        print("[AIClient] 🤖 模型: \(config.model)")
        print("[AIClient] 🔑 API Key: \(config.apiKey.prefix(min(8, config.apiKey.count)))...")

        let compressedData = try compressImage(image, maxSize: CGSize(width: 512, height: 384))
        let base64Image = compressedData.base64EncodedString()
        let dataURI = "data:image/jpeg;base64,\(base64Image)"

        print("[AIClient] 📸 图片大小: \(compressedData.count) bytes")

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
            "max_tokens": 50,
            "response_format": ["type": "json_object"]
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        if let bodyData = request.httpBody {
            print("[AIClient] 📤 请求体大小: \(bodyData.count) bytes")
        }

        print("[AIClient] ⏳ 发送请求...")
        let startTime = Date()

        let (data, response) = try await session.data(for: request)
        let elapsed = Date().timeIntervalSince(startTime)

        print("[AIClient] ✅ 收到响应 (耗时: \(String(format: "%.2f", elapsed))s)")

        guard let httpResponse = response as? HTTPURLResponse else {
            print("[AIClient] ❌ 无效的响应类型")
            throw AIError.invalidResponse
        }

        print("[AIClient] 📊 HTTP 状态码: \(httpResponse.statusCode)")

        if let responseString = String(data: data, encoding: .utf8) {
            print("[AIClient] 📥 响应内容:\n\(responseString)")
        }

        guard httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown"
            print("[AIClient] ❌ API 错误: \(errorBody)")
            throw AIError.apiError(statusCode: httpResponse.statusCode, message: errorBody)
        }

        return try parseResponse(data)
    }

    private func parseResponse(_ data: Data) throws -> AIAnalysisResponse {
        struct APIResponse: Codable {
            struct Choice: Codable {
                struct Message: Codable {
                    let content: String
                }
                let message: Message
            }
            let choices: [Choice]
        }

        let apiResponse = try jsonDecoder.decode(APIResponse.self, from: data)
        guard let content = apiResponse.choices.first?.message.content,
              let contentData = content.data(using: .utf8) else {
            print("[AIClient] ❌ 无法获取响应内容")
            throw AIError.invalidResponseFormat
        }

        print("[AIClient] 📝 AI 原始回复: \(content)")

        struct AnalysisContent: Codable {
            let state: String
            let confidence: Double
            let reason: String?
            let distractionType: String?
        }

        do {
            let analysis = try jsonDecoder.decode(AnalysisContent.self, from: contentData)
            print("[AIClient] ✅ 解析成功: state=\(analysis.state), confidence=\(analysis.confidence)")

            return AIAnalysisResponse(
                state: DetectionResult.AttentionState(rawValue: analysis.state) ?? .focused,
                confidence: analysis.confidence,
                reason: analysis.reason,
                distractionType: analysis.distractionType.flatMap { DetectionResult.DistractionType(rawValue: $0) }
            )
        } catch {
            print("[AIClient] ❌ JSON 解析失败: \(error)")
            print("[AIClient] 📄 尝试解析的内容: \(content)")
            throw AIError.invalidResponseFormat
        }
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
            systemPrompt: "你是一个专注度检测助手。分析用户是否专注于工作。只返回JSON。",
            defaultPrompt: "分析图片判断专注状态，返回:{\"state\":\"focused|distracted|away\",\"confidence\":0-1}"
        )
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
