import Foundation
import AppKit

@MainActor
class MonitorEngine: ObservableObject {
    static let shared = MonitorEngine()

    @Published var isRunning = false
    @Published var isPaused = false
    @Published var nextCheckAt: Date?
    @Published var cameraPermissionDenied = false

    private var timer: Timer?
    private let stateMachine = StateMachine.shared
    private let aiPipeline = AIPipeline()
    private let settings = Settings.shared
    private let detectionStore = DetectionStore.shared

    private init() {}

    func start() {
        Task { @MainActor in
            await startWithPermissionCheck()
        }
    }

    private func startWithPermissionCheck() async {
        guard !isRunning else {
            print("[MonitorEngine] Start requested but already running")
            return
        }

        let authorization = await CameraManager.shared.requestAuthorization()
        guard authorization == .authorized else {
            cameraPermissionDenied = true
            switch authorization {
            case .denied:
                print("[MonitorEngine] ❌ 摄像头权限未授权，无法启动监测")
                showCameraPermissionGuide(
                    title: "需要摄像头权限",
                    message: "请在 系统设置 > 隐私与安全性 > 相机 中允许 FocusGuard 使用摄像头。"
                )
            case .missingUsageDescription:
                print("[MonitorEngine] ❌ 应用缺少 NSCameraUsageDescription，无法请求权限")
                showCameraPermissionGuide(
                    title: "权限配置缺失",
                    message: "当前运行方式缺少摄像头权限描述。请使用应用包(.app)方式运行 FocusGuard。"
                )
            case .authorized:
                break
            }
            return
        }

        cameraPermissionDenied = false
        isRunning = true
        print("[MonitorEngine] ✅ 监测已启动")
        detectionStore.cleanupOldData(olderThan: settings.dataRetentionDays)
        detectionStore.updateTodayStats()
        scheduleNextCheck()
    }

    private func showCameraPermissionGuide(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "打开相机设置")
        alert.addButton(withTitle: "取消")
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            CameraManager.shared.openCameraPrivacySettings()
        }
    }

    func stop() {
        isRunning = false
        isPaused = false
        cameraPermissionDenied = false
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
