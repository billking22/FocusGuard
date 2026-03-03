# FocusGuard 技术方案文档

**版本**: v1.0  
**日期**: 2026-03-03  
**目标平台**: macOS 13.0+ (Apple Silicon)  
**分发方式**: 独立签名（非App Store）  

---

## 1. 决策摘要

| 决策项 | 选择 | 说明 |
|--------|------|------|
| **macOS版本** | 13.0+ | 使用SwiftUI MenuBarExtra原生API |
| **AI方案** | HTTP API (OpenAI兼容) | 支持本地Ollama + 云端GLM-4V/Qwen2.5-VL/OpenAI |
| **架构** | Apple Silicon Only | M1/M2/M3/M4系列芯片 |
| **分发** | 独立签名 | 无沙盒限制，支持完整系统事件监听 |
| **存储** | SQLite本地 | 纯文本统计，零图像存储 |

---

## 2. MVP功能范围 (Phase 1)

### 2.1 核心功能 ✅

| 模块 | 功能 | PRD对应 | 优先级 |
|------|------|---------|--------|
| **状态机** | 4种状态管理（正常/警觉/干预/深度专注） | FR-001 | P0 |
| **监测引擎** | 可配置时间间隔（T0/T1/T2） | FR-001 | P0 |
| **视觉分析L0** | CoreML人脸检测 + 方向分析 | FR-004 | P0 |
| **AI分析L1** | HTTP API调用（Ollama/GLM/Qwen） | FR-004 | P0 |
| **系统监听** | 锁屏/解锁检测 | FR-002 | P0 |
| **菜单栏UI** | 状态图标 + 呼吸灯动画 | FR-006 | P0 |
| **设置面板** | 基础配置（间隔、API、语音开关） | 5.1 | P0 |
| **数据存储** | SQLite统计记录 | FR-009 | P0 |
| **隐私保护** | 零图像存储实现 | FR-008 | P0 |

### 2.2 延后功能 ⏳ (Phase 2/3)

| 功能 | 延后理由 | 计划阶段 |
|------|----------|----------|
| Level 2云端AI | MVP阶段L1足够 | Phase 2 |
| 生理节律适配 | 需要7天历史数据积累 | Phase 2 |
| 摄像头占用检测 | 复杂度较高，可用手动暂停替代 | Phase 2 |
| 全屏视频检测 | 易误判，MVP暂不做自动检测 | Phase 3 |
| TTS语音提醒 | 可先使用系统通知替代 | Phase 2 |
| 数据导出 | 非核心功能 | Phase 3 |
| 生理时段策略 | 依赖节律适配 | Phase 2 |

### 2.3 需求追踪矩阵

确保所有PRD需求都有对应实现计划：

| PRD编号 | 需求描述 | MVP实现 | 状态 |
|---------|----------|---------|------|
| FR-001 | 状态机与监测周期 | ✅ 完整实现 | Phase 1 |
| FR-002 | 锁屏与情境暂停 | ⚠️ 仅锁屏检测 | Phase 1 |
| FR-003 | 生理节律适配 | ⏳ 延后 | Phase 2 |
| FR-004 | 多级AI推理流水线 | ⚠️ 仅L0+L1 | Phase 1 |
| FR-005 | 响应时间处理 | ✅ 完整实现 | Phase 1 |
| FR-006 | 渐进式提醒策略 | ⚠️ 无TTS | Phase 1 |
| FR-007 | 快速回归机制 | ✅ 完整实现 | Phase 1 |
| FR-008 | 零图像存储政策 | ✅ 完整实现 | Phase 1 |
| FR-009 | 数据统计 | ✅ 完整实现 | Phase 1 |

---

## 3. 技术架构

### 3.1 架构图

```
┌─────────────────────────────────────────────────────────────────────┐
│                        FocusGuard MVP                               │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │                      UI Layer (SwiftUI)                       │   │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐        │   │
│  │  │ MenuBarExtra │  │ SettingsView │  │ StatusIcon   │        │   │
│  │  │ (状态图标)    │  │ (设置面板)    │  │ (呼吸灯动画)  │        │   │
│  │  └──────────────┘  └──────────────┘  └──────────────┘        │   │
│  └──────────────────────────────────────────────────────────────┘   │
│                              │                                       │
│                              ▼                                       │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │                    Core Layer (Swift)                         │   │
│  │                                                              │   │
│  │   ┌────────────────┐    ┌────────────────┐                  │   │
│  │   │  StateMachine  │◀──▶│ MonitorEngine  │                  │   │
│  │   │  (状态管理)     │    │ (定时调度)      │                  │   │
│  │   └────────────────┘    └────────────────┘                  │   │
│  │            │                     │                          │   │
│  │            ▼                     ▼                          │   │
│  │   ┌────────────────┐    ┌────────────────┐                  │   │
│  │   │  EventListener │    │  AIPipeline    │                  │   │
│  │   │(锁屏/解锁监听)  │    │ (L0+L1级联)    │                  │   │
│  │   └────────────────┘    └────────────────┘                  │   │
│  │                                     │                       │   │
│  └─────────────────────────────────────┼───────────────────────┘   │
│                                        │                            │
│                              ┌─────────┴──────────┐                │
│                              ▼                    ▼                │
│  ┌─────────────────────────────────┐  ┌─────────────────────────┐ │
│  │      Vision Layer               │  │      AI Service         │ │
│  │  ┌──────────────────────────┐   │  │  ┌───────────────────┐  │ │
│  │  │  CameraManager           │   │  │  │  AIClient         │  │ │
│  │  │  (AVCaptureSession)      │   │  │  │  (HTTP API)       │  │ │
│  │  └──────────────────────────┘   │  │  └───────────────────┘  │ │
│  │  ┌──────────────────────────┐   │  │         │               │ │
│  │  │  LocalAnalyzer           │   │  │         ▼               │ │
│  │  │  (CoreML/Vision)         │   │  │  ┌──────────────┐       │ │
│  │  └──────────────────────────┘   │  │  │ Ollama API   │       │ │
│  └─────────────────────────────────┘  │  │ GLM-4V API   │       │ │
│                                        │  │ Qwen2.5-VL   │       │ │
│                                        │  └──────────────┘       │ │
│                                        └─────────────────────────┘ │
│                                                                      │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │                    Data Layer                                 │   │
│  │   ┌────────────────┐    ┌────────────────┐                  │   │
│  │   │  SQLite DB     │    │  PrivacyGuard  │                  │   │
│  │   │  (统计数据)     │    │  (零图像存储)   │                  │   │
│  │   └────────────────┘    └────────────────┘                  │   │
│  └──────────────────────────────────────────────────────────────┘   │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

### 3.2 模块职责

| 模块 | 职责 | 关键类 |
|------|------|--------|
| **StateMachine** | 管理4种监测状态，处理状态转换逻辑 | `MonitoringState`, `StateMachine` |
| **MonitorEngine** | 定时调度检测任务，管理监测生命周期 | `MonitorEngine`, `TimerManager` |
| **EventListener** | 监听系统事件（锁屏/解锁） | `SystemEventObserver` |
| **CameraManager** | 摄像头捕获，纯内存图像处理 | `CameraManager`, `FrameCapture` |
| **LocalAnalyzer** | CoreML/Vision本地视觉分析 | `FaceDetector`, `AttentionAnalyzer` |
| **AIPipeline** | AI级联调度（L0→L1） | `AIPipeline`, `AIClient` |
| **AIClient** | HTTP API客户端 | `OllamaClient`, `GLMClient`, `QwenClient` |
| **DataStore** | SQLite数据持久化 | `DetectionStore`, `StatisticsStore` |

---

## 4. 详细设计

### 4.1 状态机设计

```swift
// MARK: - 监测状态定义
enum MonitoringState: Equatable {
    case normal        // 正常监测 - 绿灯
    case alert(level: AlertLevel)  // 警觉状态
    case deepFocus     // 深度专注 - 蓝灯
    case paused        // 暂停状态
    
    enum AlertLevel {
        case first      // 一级警觉 - 黄灯呼吸
        case second     // 二级干预 - 红灯
    }
}

// MARK: - 状态机
@MainActor
class StateMachine: ObservableObject {
    @Published private(set) var currentState: MonitoringState = .normal
    
    // 状态转换表
    func transition(to newState: MonitoringState) {
        // 记录状态转换历史
        logStateTransition(from: currentState, to: newState)
        
        // 执行状态进入/退出动作
        exitState(currentState)
        currentState = newState
        enterState(newState)
    }
    
    private func enterState(_ state: MonitoringState) {
        switch state {
        case .normal:
            NotificationCenter.default.post(name: .stateChangedToNormal, object: nil)
        case .alert(let level):
            handleAlertState(level)
        case .deepFocus:
            NotificationCenter.default.post(name: .stateChangedToDeepFocus, object: nil)
        case .paused:
            break
        }
    }
}
```

### 4.2 监测引擎设计

```swift
// MARK: - 监测配置
struct MonitorConfiguration {
    var baseInterval: TimeInterval = 300  // T0 = 5分钟
    var alertInterval: TimeInterval = 120 // T1 = 2分钟
    var deepFocusInterval: TimeInterval = 480 // T2 = 8分钟
    
    // 根据状态获取当前间隔
    func interval(for state: MonitoringState) -> TimeInterval {
        switch state {
        case .normal: return baseInterval
        case .alert: return alertInterval
        case .deepFocus: return deepFocusInterval
        case .paused: return baseInterval
        }
    }
}

// MARK: - 监测引擎
@MainActor
class MonitorEngine: ObservableObject {
    @Published var isRunning = false
    @Published var nextCheckAt: Date?
    
    private var timer: Timer?
    private let stateMachine: StateMachine
    private let aiPipeline: AIPipeline
    private let config: MonitorConfiguration
    
    // 启动监测
    func start() {
        guard !isRunning else { return }
        isRunning = true
        scheduleNextCheck()
    }
    
    // 暂停监测
    func pause() {
        isRunning = false
        timer?.invalidate()
        timer = nil
    }
    
    // 调度下一次检测
    private func scheduleNextCheck() {
        guard isRunning else { return }
        
        let interval = config.interval(for: stateMachine.currentState)
        nextCheckAt = Date().addingTimeInterval(interval)
        
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            self?.performCheck()
        }
    }
    
    // 执行检测
    private func performCheck() {
        Task {
            let result = await aiPipeline.analyze()
            await processResult(result)
            scheduleNextCheck()
        }
    }
}
```

### 4.3 AI流水线设计

```swift
// MARK: - 检测结果
struct AnalysisResult {
    let state: AttentionState
    let confidence: Double
    let aiSource: AISource
    let responseTimeMs: Int
    let distractionType: DistractionType?
    
    enum AttentionState {
        case focused
        case distracted
        case away
    }
    
    enum AISource {
        case level0 // CoreML
        case level1 // Local API
        case level2 // Cloud API (MVP不支持)
    }
    
    enum DistractionType {
        case phone
        case lookingAway
        case drowsy
        case other
    }
}

// MARK: - AI流水线
class AIPipeline {
    private let localAnalyzer: LocalAnalyzer
    private let aiClient: AIClient
    
    // L0 → L1 级联
    func analyze() async -> AnalysisResult {
        let startTime = Date()
        
        // Level 0: 本地视觉分析
        let l0Result = await localAnalyzer.analyze()
        
        // 根据L0结果决定是否需要L1
        switch l0Result.state {
        case .focused where l0Result.confidence > 0.8:
            // 高置信度专注，直接使用L0结果
            return createResult(from: l0Result, source: .level0, startTime: startTime)
            
        case .distracted where l0Result.confidence > 0.8:
            // 高置信度分心，直接使用L0结果
            return createResult(from: l0Result, source: .level0, startTime: startTime)
            
        default:
            // 置信度不足，触发L1
            return await performL1Analysis(startTime: startTime)
        }
    }
    
    // Level 1: HTTP API调用
    private func performL1Analysis(startTime: Date) async -> AnalysisResult {
        do {
            // 8秒超时
            let l1Result = try await withTimeout(seconds: 8) {
                try await aiClient.analyze(image: capturedImage)
            }
            return createResult(from: l1Result, source: .level1, startTime: startTime)
        } catch {
            // L1超时或失败，回退到L0结果
            return createFallbackResult(startTime: startTime)
        }
    }
}
```

### 4.4 AI客户端设计（OpenAI兼容协议）

所有云端API均采用OpenAI兼容的消息格式，通过统一的客户端适配不同服务商。

```swift
// MARK: - AI客户端协议
protocol AIClient {
    func analyze(image: CGImage, prompt: String?) async throws -> AIAnalysisResponse
}

// MARK: - 统一OpenAI兼容客户端
class OpenAICompatibleClient: AIClient {
    private let config: AIProviderConfig
    private let session: URLSession
    private let jsonDecoder: JSONDecoder
    
    init(config: AIProviderConfig) {
        self.config = config
        self.session = URLSession(configuration: .default)
        self.jsonDecoder = JSONDecoder()
    }
    
    func analyze(image: CGImage, prompt: String? = nil) async throws -> AIAnalysisResponse {
        let url = config.baseURL.appendingPathComponent("chat/completions")
        
        // 压缩并编码图像
        let compressedData = try compressImage(image, maxSize: CGSize(width: 640, height: 480))
        let base64Image = compressedData.base64EncodedString()
        let dataURI = "data:image/jpeg;base64,\(base64Image)"
        
        // 构建消息内容
        let content: [[String: Any]] = [
            [
                "type": "text",
                "text": prompt ?? config.defaultPrompt
            ],
            [
                "type": "image_url",
                "image_url": [
                    "url": dataURI,
                    "detail": "low"  // 使用低detail减少token消耗
                ]
            ]
        ]
        
        let requestBody: [String: Any] = [
            "model": config.model,
            "messages": [
                [
                    "role": "system",
                    "content": config.systemPrompt
                ],
                [
                    "role": "user",
                    "content": content
                ]
            ],
            "temperature": 0.3,  // 低temperature提高稳定性
            "max_tokens": 150,
            "response_format": ["type": "json_object"]  // 强制JSON输出
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown"
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
            throw AIError.invalidResponseFormat
        }
        
        struct AnalysisContent: Codable {
            let state: String
            let confidence: Double
            let reason: String?
            let distractionType: String?
        }
        
        let analysis = try jsonDecoder.decode(AnalysisContent.self, from: contentData)
        
        return AIAnalysisResponse(
            state: AttentionState(rawValue: analysis.state) ?? .focused,
            confidence: analysis.confidence,
            reason: analysis.reason,
            distractionType: analysis.distractionType.flatMap { DistractionType(rawValue: $0) }
        )
    }
}

// MARK: - AI服务商配置
struct AIProviderConfig {
    let name: String
    let baseURL: URL
    let model: String
    let apiKey: String
    let systemPrompt: String
    let defaultPrompt: String
    
    // 预配置服务商
    static func glm4v(apiKey: String) -> AIProviderConfig {
        AIProviderConfig(
            name: "GLM-4V",
            baseURL: URL(string: "https://open.bigmodel.cn/api/paas/v4")!,
            model: "glm-4v",
            apiKey: apiKey,
            systemPrompt: "你是一个专注度检测助手。分析用户是否专注于工作。",
            defaultPrompt: "分析这张图片，判断用户是否专注于工作。返回JSON格式：{\"state\": \"focused|distracted|away\", \"confidence\": 0-1, \"reason\": \"原因\", \"distractionType\": \"phone|lookingAway|drowsy|other|null\"}"
        )
    }
    
    static func qwenVL(apiKey: String) -> AIProviderConfig {
        AIProviderConfig(
            name: "Qwen2.5-VL",
            baseURL: URL(string: "https://dashscope.aliyuncs.com/compatible-mode/v1")!,
            model: "qwen2.5-vl-72b-instruct",
            apiKey: apiKey,
            systemPrompt: "你是一个专注度检测助手。分析用户是否专注于工作。",
            defaultPrompt: "分析这张图片，判断用户是否专注于工作。返回JSON格式：{\"state\": \"focused|distracted|away\", \"confidence\": 0-1, \"reason\": \"原因\", \"distractionType\": \"phone|lookingAway|drowsy|other|null\"}"
        )
    }
    
    static func openAI(apiKey: String) -> AIProviderConfig {
        AIProviderConfig(
            name: "GPT-4V",
            baseURL: URL(string: "https://api.openai.com/v1")!,
            model: "gpt-4o-mini",
            apiKey: apiKey,
            systemPrompt: "You are a focus detection assistant. Analyze if the user is focused on work.",
            defaultPrompt: "Analyze this image and determine if the user is focused on work. Return JSON: {\"state\": \"focused|distracted|away\", \"confidence\": 0-1, \"reason\": \"reason\", \"distractionType\": \"phone|lookingAway|drowsy|other|null\"}"
        )
    }
    
    static func custom(baseURL: String, model: String, apiKey: String, name: String) -> AIProviderConfig {
        AIProviderConfig(
            name: name,
            baseURL: URL(string: baseURL)!,
            model: model,
            apiKey: apiKey,
            systemPrompt: "你是一个专注度检测助手。分析用户是否专注于工作。",
            defaultPrompt: "分析这张图片，判断用户是否专注于工作。返回JSON格式：{\"state\": \"focused|distracted|away\", \"confidence\": 0-1, \"reason\": \"原因\", \"distractionType\": \"phone|lookingAway|drowsy|other|null\"}"
        )
    }
    
    // 本地Ollama（OpenAI兼容模式）
    static func ollama(baseURL: String = "http://localhost:11434/v1", model: String = "llava") -> AIProviderConfig {
        AIProviderConfig(
            name: "Ollama (Local)",
            baseURL: URL(string: baseURL)!,
            model: model,
            apiKey: "ollama",  // Ollama不需要真实API Key，但协议要求字段存在
            systemPrompt: "你是一个专注度检测助手。分析用户是否专注于工作。",
            defaultPrompt: "分析这张图片，判断用户是否专注于工作。返回JSON格式：{\"state\": \"focused|distracted|away\", \"confidence\": 0-1, \"reason\": \"原因\", \"distractionType\": \"phone|lookingAway|drowsy|other|null\"}"
        )
    }
}

// MARK: - AI客户端工厂
class AIClientFactory {
    static func createClient(for provider: AIProvider) -> AIClient {
        switch provider {
        case .glm4v(let apiKey):
            return OpenAICompatibleClient(config: .glm4v(apiKey: apiKey))
        case .qwenVL(let apiKey):
            return OpenAICompatibleClient(config: .qwenVL(apiKey: apiKey))
        case .openAI(let apiKey):
            return OpenAICompatibleClient(config: .openAI(apiKey: apiKey))
        case .ollama(let baseURL, let model):
            return OpenAICompatibleClient(config: .ollama(baseURL: baseURL, model: model))
        case .custom(let config):
            return OpenAICompatibleClient(config: config)
        }
    }
}

enum AIProvider {
    case glm4v(apiKey: String)
    case qwenVL(apiKey: String)
    case openAI(apiKey: String)
    case ollama(baseURL: String, model: String)  // 本地Ollama
    case custom(config: AIProviderConfig)
}
```

### 4.5 数据存储设计

```swift
// MARK: - 数据模型
struct DetectionRecord {
    let id: UUID
    let timestamp: Date
    let state: AnalysisResult.AttentionState
    let distractionType: AnalysisResult.DistractionType?
    let confidence: Double
    let aiSource: AnalysisResult.AISource
    let responseTimeMs: Int
}

// MARK: - SQLite存储
class DetectionStore {
    private let db: Connection
    private let table = Table("detections")
    
    // 表结构
    private let id = Expression<String>("id")
    private let timestamp = Expression<Double>("timestamp")
    private let state = Expression<String>("state")
    private let distractionType = Expression<String?>("distraction_type")
    private let confidence = Expression<Double>("confidence")
    private let aiSource = Expression<String>("ai_source")
    private let responseTimeMs = Expression<Int>("response_time_ms")
    
    init() throws {
        let path = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("FocusGuard/detections.db")
        
        db = try Connection(path.path)
        try createTable()
    }
    
    private func createTable() throws {
        try db.run(table.create(ifNotExists: true) { t in
            t.column(id, primaryKey: true)
            t.column(timestamp)
            t.column(state)
            t.column(distractionType)
            t.column(confidence)
            t.column(aiSource)
            t.column(responseTimeMs)
            t.index(timestamp)
        })
    }
    
    func insert(_ record: DetectionRecord) throws {
        let insert = table.insert(
            id <- record.id.uuidString,
            timestamp <- record.timestamp.timeIntervalSince1970,
            state <- String(describing: record.state),
            distractionType <- record.distractionType.map { String(describing: $0) },
            confidence <- record.confidence,
            aiSource <- String(describing: record.aiSource),
            responseTimeMs <- record.responseTimeMs
        )
        try db.run(insert)
    }
    
    // 查询今日统计
    func todayStatistics() throws -> DayStatistics {
        let startOfDay = Calendar.current.startOfDay(for: Date())
        let startTimestamp = startOfDay.timeIntervalSince1970
        
        let query = table.filter(timestamp >= startTimestamp)
        let records = try db.prepare(query)
        
        // 计算统计数据
        var focusedCount = 0
        var distractedCount = 0
        var awayCount = 0
        
        for record in records {
            switch record[state] {
            case "focused": focusedCount += 1
            case "distracted": distractedCount += 1
            case "away": awayCount += 1
            default: break
            }
        }
        
        return DayStatistics(
            focusedCount: focusedCount,
            distractedCount: distractedCount,
            awayCount: awayCount,
            totalChecks: focusedCount + distractedCount + awayCount
        )
    }
}

// MARK: - 统计数据结构
struct DayStatistics {
    let focusedCount: Int
    let distractedCount: Int
    let awayCount: Int
    let totalChecks: Int
    
    var focusRate: Double {
        guard totalChecks > 0 else { return 0 }
        return Double(focusedCount) / Double(totalChecks)
    }
}
```

### 4.6 隐私保护实现

```swift
// MARK: - 隐私保护管理器
class PrivacyGuard {
    
    // 图像处理配置（内存中处理，不落盘）
    static let imageProcessingContext: CIContext = {
        CIContext(options: [
            .cacheIntermediates: false,      // 禁用中间缓存
            .useSoftwareRenderer: false,    // 使用GPU加速
            .highQualityDownsample: false   // 不需要高质量降采样
        ])
    }()
    
    // 压缩图像用于AI分析（内存中完成）
    static func compressForAnalysis(_ image: CGImage, maxSize: CGSize) -> Data? {
        autoreleasepool {
            let ciImage = CIImage(cgImage: image)
            
            // 计算缩放比例
            let scale = min(
                maxSize.width / CGFloat(image.width),
                maxSize.height / CGFloat(image.height),
                1.0
            )
            
            let newSize = CGSize(
                width: CGFloat(image.width) * scale,
                height: CGFloat(image.height) * scale
            )
            
            // 创建缩放滤镜
            let filter = CIFilter(name: "CILanczosScaleTransform")!
            filter.setValue(ciImage, forKey: kCIInputImageKey)
            filter.setValue(scale, forKey: kCIInputScaleKey)
            
            guard let outputImage = filter.outputImage,
                  let cgImage = imageProcessingContext.createCGImage(
                    outputImage,
                    from: outputImage.extent
                  ) else {
                return nil
            }
            
            // 转换为JPEG（内存中）
            let nsImage = NSImage(cgImage: cgImage, size: newSize)
            return nsImage.jpegRepresentation(compressionQuality: 0.6)
        }
    }
    
    // 确保临时文件立即删除
    static func secureTemporaryFile() -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = UUID().uuidString
        let fileURL = tempDir.appendingPathComponent(fileName)
        
        // 设置立即删除标记
        try? FileManager.default.setAttributes(
            [.extensionHidden: true],
            ofItemAtPath: fileURL.path
        )
        
        return fileURL
    }
}

// MARK: - 安全的相机控制器
class PrivacyProtectedCameraController {
    private let captureSession = AVCaptureSession()
    
    func captureFrame() async throws -> CVPixelBuffer {
        // 使用continuation获取最新帧
        return try await withCheckedThrowingContinuation { continuation in
            // 设置视频输出回调
            let videoOutput = AVCaptureVideoDataOutput()
            videoOutput.setSampleBufferDelegate(
                self,
                queue: DispatchQueue(label: "camera.queue")
            )
            
            // 捕获一帧后立即停止
            // ...
        }
    }
}

extension PrivacyProtectedCameraController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        // 直接处理pixelBuffer，不保存
        guard let pixelBuffer = sampleBuffer.imageBuffer else { return }
        
        // 立即进行分析，不存储
        Task {
            await analyzeFrame(pixelBuffer)
        }
    }
}
```

---

## 5. API接口文档

### 5.1 Ollama API

**Endpoint**: `POST /api/chat`

**Request**:
```json
{
  "model": "llama3.2-vision",
  "messages": [
    {
      "role": "system",
      "content": "你是一个专注度检测助手。分析用户是否专注于工作。返回JSON格式：{\"state\": \"focused|distracted|away\", \"confidence\": 0-1, \"reason\": \"原因\"}"
    },
    {
      "role": "user",
      "content": "分析这张图片",
      "images": ["base64encodedstring..."]
    }
  ],
  "stream": false,
  "format": "json"
}
```

**Response**:
```json
{
  "message": {
    "content": "{\"state\": \"focused\", \"confidence\": 0.92, \"reason\": \"用户正面朝向屏幕，眼神集中\"}"
  }
}
```

### 5.2 GLM-4V API

**Endpoint**: `POST https://open.bigmodel.cn/api/paas/v4/chat/completions`

**Headers**:
```
Authorization: Bearer {API_KEY}
Content-Type: application/json
```

**Request**:
```json
{
  "model": "glm-4v",
  "messages": [
    {
      "role": "user",
      "content": [
        {
          "type": "text",
          "text": "分析用户是否专注于工作"
        },
        {
          "type": "image_url",
          "image_url": {
            "url": "data:image/jpeg;base64,{base64_image}"
          }
        }
      ]
    }
  ]
}
```

### 5.3 Qwen2.5-VL API

**Endpoint**: `POST https://dashscope.aliyuncs.com/api/v1/services/aigc/multimodal-generation/generation`

**Headers**:
```
Authorization: Bearer {API_KEY}
Content-Type: application/json
```

---

## 6. 配置项设计

### 6.1 用户配置 (UserDefaults)

```swift
struct UserConfiguration {
    // 监测间隔
    @UserDefault("baseInterval", defaultValue: 300)
    var baseInterval: TimeInterval  // T0
    
    @UserDefault("alertInterval", defaultValue: 120)
    var alertInterval: TimeInterval  // T1
    
    @UserDefault("deepFocusInterval", defaultValue: 480)
    var deepFocusInterval: TimeInterval  // T2
    
    // AI配置
    @UserDefault("aiProvider", defaultValue: "ollama")
    var aiProvider: String  // ollama/glm/qwen
    
    @UserDefault("ollamaBaseURL", defaultValue: "http://localhost:11434")
    var ollamaBaseURL: String
    
    @UserDefault("ollamaModel", defaultValue: "llama3.2-vision")
    var ollamaModel: String
    
    // 提醒设置
    @UserDefault("voiceEnabled", defaultValue: true)
    var voiceEnabled: Bool
    
    @UserDefault("voiceVolume", defaultValue: 0.4)
    var voiceVolume: Double
    
    // 数据保留
    @UserDefault("dataRetentionDays", defaultValue: 30)
    var dataRetentionDays: Int
}
```

### 6.2 配置文件 (高级配置)

```json
// ~/.focusguard/config.json
{
  "ai": {
    "timeout": {
      "level1": 8,
      "level2": 5
    },
    "compression": {
      "maxWidth": 640,
      "maxHeight": 480,
      "quality": 60
    }
  },
  "vision": {
    "faceDetectionThreshold": 0.5,
    "phoneDetectionThreshold": 0.6
  },
  "voice": {
    "defaultMessage": "请回到工作中",
    "lowEnergyMessage": "检测到困倦，建议起身活动"
  }
}
```

---

## 7. 开发计划

### 7.1 Phase 1: Core MVP (4-6周)

| 周次 | 任务 | 产出 |
|------|------|------|
| **Week 1** | 项目搭建 + 菜单栏UI | 可运行的菜单栏应用框架 |
| **Week 2** | 摄像头集成 + L0视觉分析 | 可捕获并分析图像的基础版本 |
| **Week 3** | AI流水线 + HTTP客户端 | 完整的L0→L1级联分析 |
| **Week 4** | 状态机 + 监测引擎 | 完整的状态管理和定时调度 |
| **Week 5** | 系统事件 + 数据存储 | 锁屏检测和统计功能 |
| **Week 6** | 设置面板 + 优化 | 可配置的MVP版本 |

### 7.2 Phase 2: AI增强 (2-3周)

- TTS语音提醒
- 多模型支持（GLM-4V, Qwen2.5-VL）
- 快速回归机制完善
- 生理节律数据收集（后台运行）

### 7.3 Phase 3: 高级功能 (2周)

- 生理节律适配算法
- 摄像头占用检测
- 数据导出功能
- 高级通知设置

---

## 8. 需求追踪清单

### 8.1 PRD功能实现状态

| PRD编号 | 功能 | MVP实现 | 测试用例 |
|---------|------|---------|----------|
| FR-001 | 状态机与监测周期 | ✅ | 状态转换测试 |
| FR-001 | 时间间隔配置 | ✅ | T0/T1/T2切换测试 |
| FR-002 | 锁屏检测 | ✅ | 锁屏/解锁事件测试 |
| FR-002 | 摄像头占用检测 | ⏳ Phase 2 | - |
| FR-002 | 全屏视频检测 | ⏳ Phase 3 | - |
| FR-003 | 生理节律适配 | ⏳ Phase 2/3 | - |
| FR-004 | Level 0本地视觉 | ✅ | 人脸检测准确性测试 |
| FR-004 | Level 1本地模型 | ✅ | API集成测试 |
| FR-004 | Level 2云端模型 | ❌ 延后 | - |
| FR-005 | 响应时间处理 | ✅ | 超时/降级测试 |
| FR-006 | 渐进式提醒策略 | ⚠️ 无TTS | 状态指示器测试 |
| FR-006 | TTS语音提醒 | ⏳ Phase 2 | - |
| FR-007 | 快速回归机制 | ✅ | 快速状态恢复测试 |
| FR-008 | 零图像存储 | ✅ | 文件系统监控测试 |
| FR-009 | 数据统计 | ✅ | 数据完整性测试 |

### 8.2 非功能需求

| NFR编号 | 需求 | 实现方案 | 验收标准 |
|---------|------|----------|----------|
| 3.1 | CPU占用<10% | 后台线程+异步处理 | Activity Monitor验证 |
| 3.1 | 内存<300MB | @autoreleasepool+无缓存 | Activity Monitor验证 |
| 3.1 | 电池<2%/小时 | Timer tolerance优化 | 系统电池统计 |
| 3.2 | 零网络(纯本地) | 可选模式 | Little Snitch验证 |
| 3.2 | 摄像头指示灯<1s | 快速拍照后立即释放 | 人工观察 |
| 3.3 | 崩溃恢复 | 状态持久化 | 强制退出测试 |

---

## 9. 风险与缓解

| 风险 | 概率 | 影响 | 缓解措施 |
|------|------|------|----------|
| Ollama API不稳定 | 中 | 高 | 实现优雅降级到L0 |
| 人脸检测在低光下失效 | 高 | 中 | 提示用户改善光线 |
| AI推理时间过长 | 中 | 高 | 8秒超时+loading状态 |
| 内存泄漏 | 低 | 高 | 使用instruments检测 |
| 权限被拒绝 | 中 | 高 | 优雅降级为手动模式 |

---

## 10. 附录

### 10.1 参考资料

- [Ollama API文档](https://github.com/ollama/ollama/blob/main/docs/api.md)
- [GLM-4V API文档](https://open.bigmodel.cn/dev/api#glm-4v)
- [Qwen2.5-VL文档](https://help.aliyun.com/zh/dashscope/developer-reference/tongyi-qianwen-vl-plus-api)
- [Vision框架文档](https://developer.apple.com/documentation/vision)

### 10.2 相关开源库

- Swollama: Ollama Swift SDK
- SQLite.swift: SQLite封装
- SwiftUI MenuBarExtra: macOS 13+原生支持

---

**文档版本历史**:
- v1.0 (2026-03-03): 初始版本，MVP技术方案

**维护者**: FocusGuard开发团队  
**审核状态**: 待审核
