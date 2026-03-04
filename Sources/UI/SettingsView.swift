import SwiftUI
import AppKit

@MainActor
class SettingsWindowController {
    static let shared = SettingsWindowController()
    private var window: NSWindow?

    func showSettings() {
        if window == nil {
            let settingsView = SettingsView()
            let hostingController = NSHostingController(rootView: settingsView)

            let newWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 620, height: 560),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )

            newWindow.title = "FocusGuard Settings"
            newWindow.contentViewController = hostingController
            newWindow.center()
            newWindow.isReleasedWhenClosed = false

            window = newWindow
        }

        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

struct SettingsView: View {
    @StateObject private var settings = Settings.shared

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.08, green: 0.10, blue: 0.14),
                    Color(red: 0.12, green: 0.13, blue: 0.17)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("FocusGuard Settings")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(Color(red: 0.96, green: 0.97, blue: 0.99))
                        Text(settings.isConfigured ? "AI provider configured" : "AI provider is not configured")
                            .font(.system(size: 12, weight: .regular, design: .rounded))
                            .foregroundColor(settings.isConfigured ? .green : .orange)
                    }
                    Spacer()
                    Button {
                        closeWindow()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(Color.white.opacity(0.85))
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut(.escape, modifiers: [])
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)
                .background(Color.black.opacity(0.12))

                TabView {
                    GeneralSettingsTab()
                        .tabItem {
                            Label("General", systemImage: "slider.horizontal.3")
                        }

                    AISettingsTab()
                        .tabItem {
                            Label("AI", systemImage: "brain")
                        }

                    NotificationSettingsTab()
                        .tabItem {
                            Label("Notifications", systemImage: "bell")
                        }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
            }
        }
        .frame(width: 620, height: 560)
        .preferredColorScheme(.dark)
    }

    private func closeWindow() {
        NSApplication.shared.keyWindow?.close()
    }
}

struct GeneralSettingsTab: View {
    @StateObject private var settings = Settings.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                SettingsCard(title: "Monitoring Intervals") {
                    PickerField(title: "Base Interval (T0)") {
                        Picker("", selection: $settings.baseInterval) {
                            Text("3 minutes").tag(TimeInterval(180))
                            Text("5 minutes").tag(TimeInterval(300))
                            Text("8 minutes").tag(TimeInterval(480))
                            Text("10 minutes").tag(TimeInterval(600))
                        }
                    }

                    PickerField(title: "Alert Interval (T1)") {
                        Picker("", selection: $settings.alertInterval) {
                            Text("1 minute").tag(TimeInterval(60))
                            Text("2 minutes").tag(TimeInterval(120))
                            Text("3 minutes").tag(TimeInterval(180))
                        }
                    }

                    PickerField(title: "Deep Focus Interval (T2)") {
                        Picker("", selection: $settings.deepFocusInterval) {
                            Text("6 minutes").tag(TimeInterval(360))
                            Text("8 minutes").tag(TimeInterval(480))
                            Text("10 minutes").tag(TimeInterval(600))
                        }
                    }
                }

                SettingsCard(title: "Behavior") {
                    Toggle("Auto-resume after unlock", isOn: $settings.autoResumeAfterUnlock)
                        .toggleStyle(.switch)
                        .foregroundColor(.white.opacity(0.9))
                }

                SettingsCard(title: "Camera") {
                    Toggle("Prefer widest camera", isOn: $settings.preferWidestCamera)
                        .toggleStyle(.switch)
                        .foregroundColor(.white.opacity(0.9))

                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Zoom")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white.opacity(0.92))
                            Spacer()
                            Text(String(format: "%.1fx", settings.cameraZoomFactor))
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundColor(.white.opacity(0.75))
                                .monospacedDigit()
                        }

                        Slider(value: $settings.cameraZoomFactor, in: 0.6...2.0, step: 0.1)
                    }

                    Text("Most Mac cameras cannot go below 1.0x optically. Values below 1.0x will fallback to the widest available camera.")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(.white.opacity(0.62))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: 560, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 12)
        }
    }
}

struct AISettingsTab: View {
    @StateObject private var settings = Settings.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                SettingsCard(title: "Provider Order") {
                    Text("1) Local Ollama")
                        .foregroundColor(.white.opacity(0.92))
                    Text("2) Custom Model API (fallback)")
                        .foregroundColor(.white.opacity(0.92))
                }

                SettingsCard(title: "Ollama (Primary)") {
                    ConfigFields(
                        baseURL: $settings.ollamaBaseURL,
                        model: $settings.ollamaModel,
                        apiKey: $settings.ollamaApiKey,
                        showApiKey: false
                    )
                }

                SettingsCard(title: "Custom Model API (Fallback)") {
                    LabeledInput(title: "Provider Name") {
                        TextField("OpenRouter / GLM / Qwen / Others", text: $settings.customProviderName)
                            .textFieldStyle(.roundedBorder)
                    }

                    ConfigFields(
                        baseURL: $settings.customBaseURL,
                        model: $settings.customModel,
                        apiKey: $settings.customApiKey,
                        showApiKey: true
                    )

                    Text("Supports any OpenAI-compatible endpoint. API Key can be empty if your gateway does not require auth.")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.62))
                        .fixedSize(horizontal: false, vertical: true)
                }

                SettingsCard(title: "Timeout & Image") {
                    PickerField(title: "AI Request Timeout") {
                        Picker("", selection: $settings.aiTimeout) {
                            Text("5 seconds").tag(TimeInterval(5))
                            Text("10 seconds").tag(TimeInterval(10))
                            Text("15 seconds").tag(TimeInterval(15))
                            Text("30 seconds").tag(TimeInterval(30))
                            Text("60 seconds").tag(TimeInterval(60))
                        }
                    }

                    PickerField(title: "Max Resolution") {
                        Picker("", selection: $settings.maxImageResolution) {
                            Text("480p").tag(480)
                            Text("640p").tag(640)
                            Text("720p").tag(720)
                        }
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Compression Quality \(Int(settings.imageCompressionQuality * 100))%")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white.opacity(0.92))
                        Slider(value: $settings.imageCompressionQuality, in: 0.3...1.0, step: 0.1)
                    }
                }

                SettingsCard(title: "Connection Test") {
                    TestAPIButton()
                }
            }
            .frame(maxWidth: 560, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 12)
        }
    }
}

struct ConfigFields: View {
    @Binding var baseURL: String
    @Binding var model: String
    @Binding var apiKey: String
    let showApiKey: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            LabeledInput(title: "Base URL") {
                TextField("https://...", text: $baseURL)
                    .textFieldStyle(.roundedBorder)
            }

            LabeledInput(title: "Model") {
                TextField("model-id", text: $model)
                    .textFieldStyle(.roundedBorder)
            }

            if showApiKey {
                LabeledInput(title: "API Key") {
                    SecureField("sk-...", text: $apiKey)
                        .textFieldStyle(.roundedBorder)
                }
            }
        }
    }
}

struct NotificationSettingsTab: View {
    @StateObject private var settings = Settings.shared
    @StateObject private var logStore = AppLogStore.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                SettingsCard(title: "Voice Notifications") {
                    Toggle("Enable Voice", isOn: $settings.voiceEnabled)
                        .toggleStyle(.switch)
                        .foregroundColor(.white.opacity(0.9))

                    if settings.voiceEnabled {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Volume \(Int(settings.voiceVolume * 100))%")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white.opacity(0.92))
                            Slider(value: $settings.voiceVolume, in: 0.1...1.0)
                        }

                        LabeledInput(title: "Intervention Message") {
                            TextField("请回到工作中", text: $settings.interventionMessage)
                                .textFieldStyle(.roundedBorder)
                        }
                    }
                }

                SettingsCard(title: "Intervention Alerts") {
                    Toggle("Show bubble notification", isOn: $settings.enableBubbleNotification)
                        .toggleStyle(.switch)
                        .foregroundColor(.white.opacity(0.9))

                    Toggle("Show popup dialog", isOn: $settings.enableInterventionPopup)
                        .toggleStyle(.switch)
                        .foregroundColor(.white.opacity(0.9))
                }

                SettingsCard(title: "Data Retention") {
                    PickerField(title: "Keep History For") {
                        Picker("", selection: $settings.dataRetentionDays) {
                            Text("7 days").tag(7)
                            Text("30 days").tag(30)
                            Text("90 days").tag(90)
                        }
                    }
                }

                SettingsCard(title: "API Error Logs") {
                    HStack {
                        Button("Refresh") {
                            logStore.reload()
                        }
                        .buttonStyle(.bordered)

                        Button("Clear") {
                            logStore.clear()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)

                        Spacer()
                        Text("\(logStore.entries.count) entries")
                            .foregroundColor(.white.opacity(0.7))
                            .font(.caption)
                    }

                    ScrollView {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(logStore.entries.suffix(80).reversed()) { entry in
                                Text(entry.message)
                                    .font(.system(size: 11, weight: .regular, design: .monospaced))
                                    .foregroundColor(color(for: entry.level))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.vertical, 2)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(minHeight: 180, maxHeight: 220)
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.black.opacity(0.35))
                    )
                }
            }
            .frame(maxWidth: 560, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 12)
        }
    }

    private func color(for level: AppLogEntry.Level) -> Color {
        switch level {
        case .info: return .white.opacity(0.88)
        case .warning: return Color.yellow.opacity(0.92)
        case .error: return Color.red.opacity(0.95)
        }
    }
}

private struct SettingsCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(.white.opacity(0.95))

            content
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
    }
}

private struct PickerField<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white.opacity(0.92))

            content
                .labelsHidden()
                .pickerStyle(.menu)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.white.opacity(0.14))
                )
        }
    }
}

private struct LabeledInput<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white.opacity(0.92))
            content
        }
    }
}


struct TestAPIButton: View {
    @State private var isTesting = false

    var body: some View {
        Button(isTesting ? "Testing..." : "Test API") {
            Task {
                isTesting = true
                do {
                    let result = try await AIPipeline.shared.testConnection()
                    print("✅ API 测试成功: \(result)")
                    showAlert(title: "Success", message: result)
                } catch {
                    print("❌ API 测试失败: \(error.localizedDescription)")
                    showAlert(title: "Failed", message: error.localizedDescription)
                }
                isTesting = false
            }
        }
        .disabled(isTesting)
        .buttonStyle(.bordered)
    }

    private func showAlert(title: String, message: String) {
        Task { @MainActor in
            let alert = NSAlert()
            alert.messageText = message
            alert.alertStyle = .informational
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }
}

@MainActor
class Settings: ObservableObject {
    static let shared = Settings()

    @Published var baseInterval: TimeInterval {
        didSet { UserDefaults.standard.set(baseInterval, forKey: "baseInterval") }
    }

    @Published var alertInterval: TimeInterval {
        didSet { UserDefaults.standard.set(alertInterval, forKey: "alertInterval") }
    }

    @Published var deepFocusInterval: TimeInterval {
        didSet { UserDefaults.standard.set(deepFocusInterval, forKey: "deepFocusInterval") }
    }

    @Published var ollamaBaseURL: String {
        didSet { UserDefaults.standard.set(ollamaBaseURL, forKey: "ollamaBaseURL") }
    }

    @Published var ollamaModel: String {
        didSet { UserDefaults.standard.set(ollamaModel, forKey: "ollamaModel") }
    }

    @Published var ollamaApiKey: String {
        didSet { UserDefaults.standard.set(ollamaApiKey, forKey: "ollamaApiKey") }
    }

    @Published var customProviderName: String {
        didSet {
            UserDefaults.standard.set(customProviderName, forKey: "customProviderName")
            updateConfiguredState()
        }
    }

    @Published var customBaseURL: String {
        didSet {
            UserDefaults.standard.set(customBaseURL, forKey: "customBaseURL")
            updateConfiguredState()
        }
    }

    @Published var customModel: String {
        didSet {
            UserDefaults.standard.set(customModel, forKey: "customModel")
            updateConfiguredState()
        }
    }

    @Published var customApiKey: String {
        didSet { UserDefaults.standard.set(customApiKey, forKey: "customApiKey") }
    }

    @Published var aiTimeout: TimeInterval {
        didSet { UserDefaults.standard.set(aiTimeout, forKey: "aiTimeout") }
    }

    @Published var maxImageResolution: Int {
        didSet { UserDefaults.standard.set(maxImageResolution, forKey: "maxImageResolution") }
    }

    @Published var imageCompressionQuality: Double {
        didSet { UserDefaults.standard.set(imageCompressionQuality, forKey: "imageCompressionQuality") }
    }

    @Published var voiceEnabled: Bool {
        didSet { UserDefaults.standard.set(voiceEnabled, forKey: "voiceEnabled") }
    }

    @Published var voiceVolume: Double {
        didSet { UserDefaults.standard.set(voiceVolume, forKey: "voiceVolume") }
    }

    @Published var interventionMessage: String {
        didSet { UserDefaults.standard.set(interventionMessage, forKey: "interventionMessage") }
    }

    @Published var enableBubbleNotification: Bool {
        didSet { UserDefaults.standard.set(enableBubbleNotification, forKey: "enableBubbleNotification") }
    }

    @Published var enableInterventionPopup: Bool {
        didSet { UserDefaults.standard.set(enableInterventionPopup, forKey: "enableInterventionPopup") }
    }

    @Published var dataRetentionDays: Int {
        didSet { UserDefaults.standard.set(dataRetentionDays, forKey: "dataRetentionDays") }
    }

    @Published var autoResumeAfterUnlock: Bool {
        didSet { UserDefaults.standard.set(autoResumeAfterUnlock, forKey: "autoResumeAfterUnlock") }
    }

    @Published var preferWidestCamera: Bool {
        didSet { UserDefaults.standard.set(preferWidestCamera, forKey: "preferWidestCamera") }
    }

    @Published var cameraZoomFactor: Double {
        didSet { UserDefaults.standard.set(cameraZoomFactor, forKey: "cameraZoomFactor") }
    }

    @Published var isConfigured: Bool = false

    private func updateConfiguredState() {
        let hasOllama = !ollamaBaseURL.isEmpty && !ollamaModel.isEmpty
        let hasCustom = !customBaseURL.isEmpty && !customModel.isEmpty
        isConfigured = hasOllama || hasCustom
    }

    private init() {
        let defaults = UserDefaults.standard

        baseInterval = defaults.object(forKey: "baseInterval") as? TimeInterval ?? 300
        alertInterval = defaults.object(forKey: "alertInterval") as? TimeInterval ?? 120
        deepFocusInterval = defaults.object(forKey: "deepFocusInterval") as? TimeInterval ?? 480

        ollamaBaseURL = defaults.string(forKey: "ollamaBaseURL") ?? "http://localhost:11434/v1"
        ollamaModel = defaults.string(forKey: "ollamaModel") ?? "llava"
        ollamaApiKey = defaults.string(forKey: "ollamaApiKey") ?? ""

        customProviderName = defaults.string(forKey: "customProviderName") ?? "Custom"
        customBaseURL = defaults.string(forKey: "customBaseURL") ?? ""
        customModel = defaults.string(forKey: "customModel") ?? ""
        customApiKey = defaults.string(forKey: "customApiKey") ?? ""

        aiTimeout = defaults.object(forKey: "aiTimeout") as? TimeInterval ?? 10
        maxImageResolution = defaults.object(forKey: "maxImageResolution") as? Int ?? 640
        imageCompressionQuality = defaults.object(forKey: "imageCompressionQuality") as? Double ?? 0.6

        voiceEnabled = defaults.object(forKey: "voiceEnabled") as? Bool ?? false
        voiceVolume = defaults.object(forKey: "voiceVolume") as? Double ?? 0.4
        interventionMessage = defaults.string(forKey: "interventionMessage") ?? "请回到工作中"
        enableBubbleNotification = defaults.object(forKey: "enableBubbleNotification") as? Bool ?? true
        enableInterventionPopup = defaults.object(forKey: "enableInterventionPopup") as? Bool ?? false
        dataRetentionDays = defaults.object(forKey: "dataRetentionDays") as? Int ?? 30
        autoResumeAfterUnlock = defaults.object(forKey: "autoResumeAfterUnlock") as? Bool ?? true
        preferWidestCamera = defaults.object(forKey: "preferWidestCamera") as? Bool ?? true
        cameraZoomFactor = defaults.object(forKey: "cameraZoomFactor") as? Double ?? 1.0

        migrateLegacyProviderSettings(defaults: defaults)

        updateConfiguredState()
    }

    private func migrateLegacyProviderSettings(defaults: UserDefaults) {
        // 从旧版 GLM/Qwen 配置自动迁移到 custom provider（仅在 custom 未填写时）
        guard customBaseURL.isEmpty || customModel.isEmpty else { return }

        let legacyGLMBase = defaults.string(forKey: "glmBaseURL") ?? ""
        let legacyGLMModel = defaults.string(forKey: "glmModel") ?? ""
        let legacyGLMKey = defaults.string(forKey: "glmApiKey") ?? ""

        let legacyQwenBase = defaults.string(forKey: "qwenBaseURL") ?? ""
        let legacyQwenModel = defaults.string(forKey: "qwenModel") ?? ""
        let legacyQwenKey = defaults.string(forKey: "qwenApiKey") ?? ""

        if !legacyGLMBase.isEmpty && !legacyGLMModel.isEmpty {
            customProviderName = "GLM"
            customBaseURL = legacyGLMBase
            customModel = legacyGLMModel
            customApiKey = legacyGLMKey
            return
        }

        if !legacyQwenBase.isEmpty && !legacyQwenModel.isEmpty {
            customProviderName = "Qwen"
            customBaseURL = legacyQwenBase
            customModel = legacyQwenModel
            customApiKey = legacyQwenKey
        }
    }
}
