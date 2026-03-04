import Foundation
import AppKit
@preconcurrency
import UserNotifications

@MainActor
final class AlertNotifier: NSObject {
    static let shared = AlertNotifier()

    private let settings = Settings.shared
    private let logger = AppLogStore.shared
    private let speech = NSSpeechSynthesizer()
    private override init() {
        super.init()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(stateDidChange),
            name: .stateChanged,
            object: nil
        )
    }

    @objc private func stateDidChange() {
        handleStateChange()
    }

    private func handleStateChange() {
        guard case .alert(let level) = StateMachine.shared.currentState else { return }
        guard level == .second else { return }

        let message = settings.interventionMessage
        logger.log(level: .warning, category: "Intervention", message: "Triggered intervention: \(message)")

        if settings.voiceEnabled {
            speak(message)
        }

        if settings.enableBubbleNotification {
            sendBubble(title: "FocusGuard", message: message)
        }

        if settings.enableInterventionPopup {
            showPopup(message: message)
        }
    }

    private func speak(_ message: String) {
        speech.stopSpeaking()
        speech.rate = 180
        speech.volume = Float(settings.voiceVolume)
        speech.startSpeaking(message)
    }

    private func sendBubble(title: String, message: String) {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, error in
            Task { @MainActor in
                if let error {
                    self.logger.log(level: .error, category: "Notification", message: "Authorization failed: \(error.localizedDescription)")
                    return
                }
                guard granted else {
                    self.logger.log(level: .warning, category: "Notification", message: "Authorization denied")
                    return
                }

                let content = UNMutableNotificationContent()
                content.title = title
                content.body = message
                content.sound = .default

                let request = UNNotificationRequest(
                    identifier: UUID().uuidString,
                    content: content,
                    trigger: nil
                )

                Task { @MainActor in
                    do {
                        try await center.add(request)
                    } catch {
                        self.logger.log(level: .error, category: "Notification", message: "Send failed: \(error.localizedDescription)")
                    }
                }
            }
        }
    }

    private func showPopup(message: String) {
        let alert = NSAlert()
        alert.messageText = "FocusGuard 提醒"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "知道了")
        alert.runModal()
    }
}
