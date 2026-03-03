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
                contentRect: NSRect(x: 0, y: 0, width: 500, height: 500),
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
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button("Close") {
                    closeWindow()
                }
                .keyboardShortcut(.escape, modifiers: [])
            }
            .padding(.horizontal)
            .padding(.top, 8)

            TabView {
                GeneralSettingsTab()
                    .tabItem {
                        Label("General", systemImage: "gear")
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
            .padding(.horizontal)
            .padding(.bottom)
        }
        .frame(width: 500, height: 500)
    }

    private func closeWindow() {
        NSApplication.shared.keyWindow?.close()
    }
}

struct GeneralSettingsTab: View {
    @StateObject private var settings = Settings.shared

    var body: some View {
        Form {
            Section("Monitoring Intervals") {
                Picker("Base Interval (T0)", selection: $settings.baseInterval) {
                    Text("3 minutes").tag(TimeInterval(180))
                    Text("5 minutes").tag(TimeInterval(300))
                    Text("8 minutes").tag(TimeInterval(480))
                    Text("10 minutes").tag(TimeInterval(600))
                }

                Picker("Alert Interval (T1)", selection: $settings.alertInterval) {
                    Text("1 minute").tag(TimeInterval(60))
                    Text("2 minutes").tag(TimeInterval(120))
                    Text("3 minutes").tag(TimeInterval(180))
                }

                Picker("Deep Focus Interval (T2)", selection: $settings.deepFocusInterval) {
                    Text("6 minutes").tag(TimeInterval(360))
                    Text("8 minutes").tag(TimeInterval(480))
                    Text("10 minutes").tag(TimeInterval(600))
                }
            }

            Section("Behavior") {
                Toggle("Auto-resume after unlock", isOn: $settings.autoResumeAfterUnlock)
            }
        }
        .padding()
    }
}

struct AISettingsTab: View {
    @StateObject private var settings = Settings.shared

    var body: some View {
        Form {
            Section("AI Provider") {
                Picker("Provider", selection: $settings.aiProvider) {
                    Text("Ollama (Local)").tag("ollama")
                    Text("GLM (Zhipu)").tag("glm")
                    Text("Qwen (Alibaba)").tag("qwen")
                }
                .pickerStyle(.segmented)
            }

            Section("Configuration") {
                if settings.aiProvider == "ollama" {
                    ConfigFields(
                        baseURL: $settings.ollamaBaseURL,
                        model: $settings.ollamaModel,
                        apiKey: $settings.ollamaApiKey,
                        showApiKey: false
                    )
                } else if settings.aiProvider == "glm" {
                    ConfigFields(
                        baseURL: $settings.glmBaseURL,
                        model: $settings.glmModel,
                        apiKey: $settings.glmApiKey,
                        showApiKey: true
                    )
                } else if settings.aiProvider == "qwen" {
                    ConfigFields(
                        baseURL: $settings.qwenBaseURL,
                        model: $settings.qwenModel,
                        apiKey: $settings.qwenApiKey,
                        showApiKey: true
                    )
                }
            }

            Section("Timeout") {
                Picker("AI Request Timeout", selection: $settings.aiTimeout) {
                    Text("5 seconds").tag(TimeInterval(5))
                    Text("10 seconds").tag(TimeInterval(10))
                    Text("15 seconds").tag(TimeInterval(15))
                    Text("30 seconds").tag(TimeInterval(30))
                    Text("60 seconds").tag(TimeInterval(60))
                }
            }

            Section("Test") {
                TestAPIButton()
            }

            Section("Image Compression") {
                Picker("Max Resolution", selection: $settings.maxImageResolution) {
                    Text("480p").tag(480)
                    Text("640p").tag(640)
                    Text("720p").tag(720)
                }

                Slider(value: $settings.imageCompressionQuality, in: 0.3...1.0, step: 0.1) {
                    Text("Quality: \(Int(settings.imageCompressionQuality * 100))%")
                }
            }
        }
        .padding()
    }
}

struct ConfigFields: View {
    @Binding var baseURL: String
    @Binding var model: String
    @Binding var apiKey: String
    let showApiKey: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("Base URL", text: $baseURL)
                .textFieldStyle(RoundedBorderTextFieldStyle())

            TextField("Model", text: $model)
                .textFieldStyle(RoundedBorderTextFieldStyle())

            if showApiKey {
                SecureField("API Key", text: $apiKey)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
        }
    }
}

struct NotificationSettingsTab: View {
    @StateObject private var settings = Settings.shared

    var body: some View {
        Form {
            Section("Voice Notifications") {
                Toggle("Enable Voice", isOn: $settings.voiceEnabled)

                if settings.voiceEnabled {
                    Slider(value: $settings.voiceVolume, in: 0.1...1.0) {
                        Text("Volume: \(Int(settings.voiceVolume * 100))%")
                    }

                    TextField("Intervention Message", text: $settings.interventionMessage)
                }
            }

            Section("Data Retention") {
                Picker("Keep History For", selection: $settings.dataRetentionDays) {
                    Text("7 days").tag(7)
                    Text("30 days").tag(30)
                    Text("90 days").tag(90)
                }
            }
        }
        .padding()
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

    @Published var aiProvider: String {
        didSet {
            UserDefaults.standard.set(aiProvider, forKey: "aiProvider")
            updateConfiguredState()
        }
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

    @Published var glmBaseURL: String {
        didSet { UserDefaults.standard.set(glmBaseURL, forKey: "glmBaseURL") }
    }

    @Published var glmModel: String {
        didSet { UserDefaults.standard.set(glmModel, forKey: "glmModel") }
    }

    @Published var glmApiKey: String {
        didSet { UserDefaults.standard.set(glmApiKey, forKey: "glmApiKey") }
    }

    @Published var qwenBaseURL: String {
        didSet { UserDefaults.standard.set(qwenBaseURL, forKey: "qwenBaseURL") }
    }

    @Published var qwenModel: String {
        didSet { UserDefaults.standard.set(qwenModel, forKey: "qwenModel") }
    }

    @Published var qwenApiKey: String {
        didSet { UserDefaults.standard.set(qwenApiKey, forKey: "qwenApiKey") }
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

    @Published var dataRetentionDays: Int {
        didSet { UserDefaults.standard.set(dataRetentionDays, forKey: "dataRetentionDays") }
    }

    @Published var autoResumeAfterUnlock: Bool {
        didSet { UserDefaults.standard.set(autoResumeAfterUnlock, forKey: "autoResumeAfterUnlock") }
    }

    @Published var isConfigured: Bool = false

    private func updateConfiguredState() {
        let hasOllama = !ollamaBaseURL.isEmpty && !ollamaModel.isEmpty
        let hasGLM = !glmBaseURL.isEmpty && !glmModel.isEmpty && !glmApiKey.isEmpty
        let hasQwen = !qwenBaseURL.isEmpty && !qwenModel.isEmpty && !qwenApiKey.isEmpty
        isConfigured = hasOllama || hasGLM || hasQwen
    }

    private init() {
        let defaults = UserDefaults.standard

        baseInterval = defaults.object(forKey: "baseInterval") as? TimeInterval ?? 300
        alertInterval = defaults.object(forKey: "alertInterval") as? TimeInterval ?? 120
        deepFocusInterval = defaults.object(forKey: "deepFocusInterval") as? TimeInterval ?? 480

        aiProvider = defaults.string(forKey: "aiProvider") ?? "ollama"

        ollamaBaseURL = defaults.string(forKey: "ollamaBaseURL") ?? "http://localhost:11434/v1"
        ollamaModel = defaults.string(forKey: "ollamaModel") ?? "llava"
        ollamaApiKey = defaults.string(forKey: "ollamaApiKey") ?? ""

        glmBaseURL = defaults.string(forKey: "glmBaseURL") ?? "https://open.bigmodel.cn/api/paas/v4"
        glmModel = defaults.string(forKey: "glmModel") ?? "glm-4v-flash"
        glmApiKey = defaults.string(forKey: "glmApiKey") ?? ""

        qwenBaseURL = defaults.string(forKey: "qwenBaseURL") ?? "https://dashscope.aliyuncs.com/compatible-mode/v1"
        qwenModel = defaults.string(forKey: "qwenModel") ?? "qwen2.5-vl-3b-instruct"
        qwenApiKey = defaults.string(forKey: "qwenApiKey") ?? ""

        aiTimeout = defaults.object(forKey: "aiTimeout") as? TimeInterval ?? 10
        maxImageResolution = defaults.object(forKey: "maxImageResolution") as? Int ?? 640
        imageCompressionQuality = defaults.object(forKey: "imageCompressionQuality") as? Double ?? 0.6

        voiceEnabled = defaults.object(forKey: "voiceEnabled") as? Bool ?? false
        voiceVolume = defaults.object(forKey: "voiceVolume") as? Double ?? 0.4
        interventionMessage = defaults.string(forKey: "interventionMessage") ?? "请回到工作中"
        dataRetentionDays = defaults.object(forKey: "dataRetentionDays") as? Int ?? 30
        autoResumeAfterUnlock = defaults.object(forKey: "autoResumeAfterUnlock") as? Bool ?? true

        updateConfiguredState()
    }
}
