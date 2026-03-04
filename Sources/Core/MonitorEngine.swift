import Foundation

@MainActor
class MonitorEngine: ObservableObject {
    static let shared = MonitorEngine()

    @Published var isRunning = false
    @Published var isPaused = false
    @Published var nextCheckAt: Date?

    private var timer: Timer?
    private let stateMachine = StateMachine.shared
    private let aiPipeline = AIPipeline()
    private let settings = Settings.shared
    private let detectionStore = DetectionStore.shared

    private init() {}

    func start() {
        guard !isRunning else {
            print("[MonitorEngine] Start requested but already running")
            return
        }
        isRunning = true
        print("[MonitorEngine] ✅ 监测已启动")
        detectionStore.cleanupOldData(olderThan: settings.dataRetentionDays)
        detectionStore.updateTodayStats()
        scheduleNextCheck()
    }

    func stop() {
        isRunning = false
        isPaused = false
        timer?.invalidate()
        timer = nil
        nextCheckAt = nil
        print("[MonitorEngine] ⏹️ 监测已停止")
    }

    func pause() {
        isRunning = false
        isPaused = true
        stateMachine.pause()
        timer?.invalidate()
        timer = nil
        nextCheckAt = nil
        print("[MonitorEngine] ⏸️ 监测已暂停")
    }

    func resume() {
        isRunning = true
        isPaused = false
        stateMachine.resume()
        print("[MonitorEngine] ▶️ 监测已恢复")
        scheduleNextCheck()
    }

    private func scheduleNextCheck() {
        guard isRunning else {
            print("[MonitorEngine] ⚠️ 监测未运行，跳过调度")
            return
        }

        let interval = currentInterval()
        nextCheckAt = Date().addingTimeInterval(interval)
        let minutes = Int(interval / 60)

        print("[MonitorEngine] ⏱️ 下次监测将在 \(minutes) 分钟后 (\(nextCheckAt!.formatted(date: .omitted, time: .shortened)))")

        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                await self.performCheck()
            }
        }
    }

    private func currentInterval() -> TimeInterval {
        switch stateMachine.currentState {
        case .normal:
            print("[MonitorEngine] 📊 当前间隔: 正常状态 = \(Int(settings.baseInterval / 60)) 分钟")
            return settings.baseInterval
        case .alert:
            print("[MonitorEngine] 📊 当前间隔: 警觉状态 = \(Int(settings.alertInterval / 60)) 分钟")
            return settings.alertInterval
        case .deepFocus:
            print("[MonitorEngine] 📊 当前间隔: 深度专注 = \(Int(settings.deepFocusInterval / 60)) 分钟")
            return settings.deepFocusInterval
        case .paused:
            return settings.baseInterval
        }
    }

    private func performCheck() async {
        guard isRunning else {
            print("[MonitorEngine] ⚠️ 监测未运行，跳过本次检查")
            return
        }

        print("[MonitorEngine] 🔍 开始监测...")
        let checkStart = Date()

        do {
            let result = try await aiPipeline.analyze()
            let responseTimeMs = Int(Date().timeIntervalSince(checkStart) * 1000)
            let source = result.source == .level0 ? "L0(本地)" : "L1(AI)"
            print("[MonitorEngine] ✅ 监测完成: 状态=\(result.state.rawValue), 置信度=\(String(format: "%.2f", result.confidence)), 来源=\(source)")
            detectionStore.insert(
                DetectionRecord(
                    state: result.state,
                    confidence: result.confidence,
                    source: result.source,
                    responseTimeMs: responseTimeMs
                )
            )
            stateMachine.reportDetectionResult(result)
            scheduleNextCheck()
        } catch AIError.timeout {
            print("[MonitorEngine] ⏰ 监测超时")
            scheduleNextCheck()
        } catch {
            print("[MonitorEngine] ❌ 监测失败: \(error)")
            scheduleNextCheck()
        }
    }
}
