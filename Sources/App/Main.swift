import SwiftUI

@main
struct FocusGuardApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
        } label: {
            StatusBarIcon()
        }
        .menuBarExtraStyle(.window)
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
    
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        MonitorEngine.shared.stop()
        return .terminateNow
    }
}

struct StatusBarIcon: View {
    @StateObject private var stateMachine = StateMachine.shared
    
    var body: some View {
        Image(systemName: iconName)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 18, height: 18)
            .foregroundColor(iconColor)
            .modifier(StatusAnimationModifier(state: stateMachine.currentState))
    }
    
    private var iconName: String {
        switch stateMachine.currentState {
        case .normal: return "circle.fill"
        case .alert(let level): return level == .first ? "exclamationmark.circle.fill" : "xmark.circle.fill"
        case .deepFocus: return "star.circle.fill"
        case .paused: return "pause.circle.fill"
        }
    }
    
    private var iconColor: Color {
        switch stateMachine.currentState {
        case .normal: return .green
        case .alert(let level): return level == .first ? .yellow : .red
        case .deepFocus: return .blue
        case .paused: return .gray
        }
    }
}

struct StatusAnimationModifier: ViewModifier {
    let state: MonitoringState
    @State private var isAnimating = false
    
    func body(content: Content) -> some View {
        content
            .opacity(shouldPulse ? (isAnimating ? 0.3 : 1.0) : 1.0)
            .animation(
                shouldPulse ? .easeInOut(duration: 2.0).repeatForever(autoreverses: true) : .default,
                value: isAnimating
            )
            .onAppear { isAnimating = shouldPulse }
            .onChange(of: state) { _ in isAnimating = shouldPulse }
    }
    
    private var shouldPulse: Bool {
        if case .alert(let level) = state, level == .first { return true }
        return false
    }
}
