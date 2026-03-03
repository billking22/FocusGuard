import Foundation
import AppKit

@MainActor
class SystemEventObserver: ObservableObject {
    static let shared = SystemEventObserver()
    
    @Published var isScreenLocked = false
    @Published var isSystemSleeping = false
    
    private init() {
        setupObservers()
    }
    
    private func setupObservers() {
        let center = DistributedNotificationCenter.default()
        
        center.addObserver(
            self,
            selector: #selector(screenLocked),
            name: NSNotification.Name("com.apple.screenIsLocked"),
            object: nil
        )
        
        center.addObserver(
            self,
            selector: #selector(screenUnlocked),
            name: NSNotification.Name("com.apple.screenIsUnlocked"),
            object: nil
        )
        
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(systemWillSleep),
            name: NSWorkspace.willSleepNotification,
            object: nil
        )
        
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(systemDidWake),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )
    }
    
    @objc private func screenLocked() {
        isScreenLocked = true
        print("[SystemEvent] 🔒 屏幕已锁定")
        MonitorEngine.shared.pause()
    }

    @objc private func screenUnlocked() {
        isScreenLocked = false
        print("[SystemEvent] 🔓 屏幕已解锁")
        if UserDefaults.standard.bool(forKey: "autoResumeAfterUnlock") {
            print("[SystemEvent] ▶️ 自动恢复监测")
            MonitorEngine.shared.resume()
        }
    }

    @objc private func systemWillSleep() {
        isSystemSleeping = true
        print("[SystemEvent] 💤 系统即将睡眠")
        MonitorEngine.shared.pause()
    }

    @objc private func systemDidWake() {
        isSystemSleeping = false
        print("[SystemEvent] ☀️ 系统已唤醒")
    }
}
