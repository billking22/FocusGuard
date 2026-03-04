import Foundation
import CoreImage

@MainActor
class AIPipeline {
    static let shared = AIPipeline()
    private let localAnalyzer = LocalAnalyzer()
    private var capturedImage: CGImage?
    private let settings = Settings.shared
    private let logger = AppLogStore.shared

    public init() {}

    func analyze() async throws -> DetectionResult {
        let startTime = Date()

        let authorized = await CameraManager.shared.checkAuthorization()
        guard authorized else {
            throw AIError.notAuthorized
        }

        guard let image = try await CameraManager.shared.captureFrame() else {
            print("[AIPipeline] ⚠️ Frame capture failed, marking as away")
            return DetectionResult(state: .away, confidence: 1.0, source: .level0)
        }

        self.capturedImage = image

        let l0Result = await localAnalyzer.analyze(image: image)

        if !l0Result.hasPresence {
            print("[AIPipeline] 👤 L0 未检测到人脸/人体，判定 away")
            return DetectionResult(state: .away, confidence: 1.0, source: .level0)
        }

        print("[AIPipeline] ✅ L0 presence: hasFace=\(l0Result.hasFace), hasPerson=\(l0Result.hasPerson)")

        return try await performL1Analysis(image: image, startTime: startTime)
    }

    func testConnection() async throws -> String {
        let startTime = Date()
        print("[AIPipeline] 🔧 开始API连接测试...")

        let authorized = await CameraManager.shared.checkAuthorization()
        guard authorized else {
            print("[AIPipeline] ❌ 摄像头权限未授权")
            throw AIError.notAuthorized
        }

        guard let image = try await CameraManager.shared.captureFrame() else {
            print("[AIPipeline] ⚠️ 图像采集失败")
            throw AIError.notAuthorized
        }

        let configs = buildProviderConfigs()

        for (index, config) in configs.enumerated() {
            print("[AIPipeline] 🔗 [\(index + 1)/\(configs.count)] 测试 \(config.name)")
            print("[AIPipeline]    URL: \(config.baseURL)")
            print("[AIPipeline]    Model: \(config.model)")
            print("[AIPipeline]    API Key: \(config.apiKey.isEmpty ? "(空)" : "\(config.apiKey.prefix(8))...")")

            let client = AIClientFactory.createClient(
                baseURL: config.baseURL,
                model: config.model,
                apiKey: config.apiKey,
                name: config.name
            )

            let requestStart = Date()
            do {
                let result = try await withTimeout(seconds: settings.aiTimeout) {
                    try await client.analyze(image: image, prompt: nil)
                }
                let duration = Date().timeIntervalSince(requestStart)
                print("[AIPipeline]    ✅ 成功 (\(String(format: "%.2f", duration))s): \(result.state.rawValue), 置信度=\(String(format: "%.2f", result.confidence))")
                return "✅ \(config.name) 连接成功\n响应时间: \(String(format: "%.2f", duration))s\n状态: \(result.state.rawValue)\n置信度: \(String(format: "%.2f", result.confidence))"
            } catch AIError.timeout {
                let duration = Date().timeIntervalSince(requestStart)
                print("[AIPipeline]    ⏰ 超时 (\(String(format: "%.2f", duration))s)")
                logger.log(level: .error, category: "API", message: "[\(config.name)] timeout in testConnection (\(String(format: "%.2f", duration))s)")
                throw AIError.timeout
            } catch let error as AIError {
                let duration = Date().timeIntervalSince(requestStart)
                print("[AIPipeline]    ❌ 错误 (\(String(format: "%.2f", duration))s): \(error)")
                logger.log(level: .error, category: "API", message: "[\(config.name)] testConnection failed: \(error)")
                throw error
            } catch {
                let duration = Date().timeIntervalSince(requestStart)
                print("[AIPipeline]    ❌ 失败 (\(String(format: "%.2f", duration))s): \(error.localizedDescription)")
                logger.log(level: .error, category: "API", message: "[\(config.name)] testConnection error: \(error.localizedDescription)")
                throw error
            }
        }

        let totalDuration = Date().timeIntervalSince(startTime)
        print("[AIPipeline] ⚠️ 所有API源测试失败，总耗时: \(String(format: "%.2f", totalDuration))s")
        throw AIError.apiError(statusCode: 0, message: "所有API源均无法连接")
    }

    private func performL1Analysis(image: CGImage, startTime: Date) async throws -> DetectionResult {
        let timeoutSeconds = settings.aiTimeout

        let configs = buildProviderConfigs()

        for (index, config) in configs.enumerated() {
            print("[AIPipeline] 🤖 [\(index + 1)/\(configs.count)] Trying \(config.name) (timeout: \(Int(timeoutSeconds))s)")

            let requestStart = Date()
            let client = AIClientFactory.createClient(
                baseURL: config.baseURL,
                model: config.model,
                apiKey: config.apiKey,
                name: config.name
            )

            do {
                let l1Result = try await withTimeout(seconds: timeoutSeconds) {
                    try await client.analyze(image: image, prompt: nil)
                }
                let duration = Date().timeIntervalSince(requestStart)
                print("[AIPipeline] ✅ \(config.name) success (\(String(format: "%.2fs", duration))): state=\(l1Result.state.rawValue), confidence=\(String(format: "%.2f", l1Result.confidence))")
                return createResult(from: l1Result, source: .level1, startTime: startTime)
            } catch AIError.timeout {
                let duration = Date().timeIntervalSince(requestStart)
                print("[AIPipeline] ⏰ \(config.name) timed out (\(String(format: "%.2fs", duration)))")
                logger.log(level: .error, category: "API", message: "[\(config.name)] timed out (\(String(format: "%.2fs", duration)))")
                continue
            } catch AIError.apiError(let status, let message) {
                let duration = Date().timeIntervalSince(requestStart)
                print("[AIPipeline] ❌ \(config.name) failed (\(String(format: "%.2fs", duration))): HTTP \(status) - \(message)")
                logger.log(level: .error, category: "API", message: "[\(config.name)] HTTP \(status): \(message)")
                continue
            } catch {
                let duration = Date().timeIntervalSince(requestStart)
                print("[AIPipeline] ❌ \(config.name) failed (\(String(format: "%.2fs", duration))): \(error.localizedDescription)")
                logger.log(level: .error, category: "API", message: "[\(config.name)] error: \(error.localizedDescription)")
                continue
            }
        }

        print("[AIPipeline] ⚠️ 所有AI源均失败，降级到保守策略(假设专注)")
        logger.log(level: .warning, category: "API", message: "All providers failed, fallback to conservative strategy")
        return DetectionResult(state: .focused, confidence: 0.5, source: .level0)
    }

    private func buildProviderConfigs() -> [(name: String, baseURL: String, model: String, apiKey: String)] {
        var configs: [(name: String, baseURL: String, model: String, apiKey: String)] = []

        // Ollama 优先：如果配置了 Ollama，始终排在第一位
        if !settings.ollamaBaseURL.isEmpty && !settings.ollamaModel.isEmpty {
            configs.append((
                name: "Ollama",
                baseURL: settings.ollamaBaseURL,
                model: settings.ollamaModel,
                apiKey: settings.ollamaApiKey.isEmpty ? "ollama" : settings.ollamaApiKey
            ))
        }

        // 追加一个“自定义大模型”作为 fallback（任意 OpenAI-compatible 接口）
        if !settings.customBaseURL.isEmpty && !settings.customModel.isEmpty {
            configs.append((
                name: settings.customProviderName.isEmpty ? "Custom" : settings.customProviderName,
                baseURL: settings.customBaseURL,
                model: settings.customModel,
                apiKey: settings.customApiKey
            ))
        }

        if configs.isEmpty {
            print("[AIPipeline] ⚠️ 无可用 AI provider 配置")
        } else {
            print("[AIPipeline] 📋 Provider 优先级: \(configs.map { $0.name }.joined(separator: " → "))")
        }

        return configs
    }

    private func createResult(from aiResponse: AIAnalysisResponse, source: DetectionResult.AISource, startTime: Date) -> DetectionResult {
        let duration = Date().timeIntervalSince(startTime)
        print("[AIPipeline] 📦 创建检测结果，总耗时: \(String(format: "%.2f", duration))s")
        return DetectionResult(
            state: aiResponse.state,
            confidence: aiResponse.confidence,
            source: source
        )
    }
}

func withTimeout<T: Sendable>(seconds: TimeInterval, operation: @escaping @Sendable () async throws -> T) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask {
            try await operation()
        }

        group.addTask {
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            throw AIError.timeout
        }

        let result = try await group.next()!
        group.cancelAll()
        return result
    }
}

enum AIError: Error {
    case timeout
    case invalidResponse
    case apiError(statusCode: Int, message: String)
    case invalidResponseFormat
    case notAuthorized
}
