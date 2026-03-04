import SwiftUI
import AppKit

struct MenuBarView: View {
    @StateObject private var stateMachine = StateMachine.shared
    @StateObject private var engine = MonitorEngine.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            StatusSection()

            Divider()

            ControlButtons()

            Divider()

            TestButton()

            Divider()

            StatisticsSection()

            Divider()

            Button("Settings...") {
                SettingsWindowController.shared.showSettings()
            }

            Button("Quit") {
                NSApp.terminate(nil)
            }
        }
        .padding()
        .frame(width: 280)
    }
}

struct StatusSection: View {
    @StateObject private var stateMachine = StateMachine.shared
    @StateObject private var engine = MonitorEngine.shared

    var body: some View {
        HStack {
            StatusIndicator(state: stateMachine.currentState)

            VStack(alignment: .leading) {
                Text(statusText)
                    .font(.headline)
                if let nextCheck = engine.nextCheckAt {
                    Text("Next check: \(nextCheck, style: .time)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    private var statusText: String {
        switch stateMachine.currentState {
        case .normal: return "Monitoring"
        case .alert(let level): return level == .first ? "Alert" : "Intervention"
        case .deepFocus: return "Deep Focus"
        case .paused: return "Paused"
        }
    }
}

struct StatusIndicator: View {
    let state: MonitoringState

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 12, height: 12)
    }

    private var color: Color {
        switch state {
        case .normal: return .green
        case .alert(let level): return level == .first ? .yellow : .red
        case .deepFocus: return .blue
        case .paused: return .gray
        }
    }
}

struct ControlButtons: View {
    @StateObject private var engine = MonitorEngine.shared
    @StateObject private var settings = Settings.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                if engine.isRunning {
                    Button("Pause") {
                        engine.pause()
                    }
                } else if engine.isPaused {
                    Button("Resume") {
                        engine.resume()
                    }
                } else {
                    Button("Start") {
                        engine.start()
                    }
                    .disabled(!settings.isConfigured)
                }

                Button("Stop") {
                    engine.stop()
                }
                .disabled(!engine.isRunning && !engine.isPaused)
            }

            if !settings.isConfigured {
                Text("⚠️ Please configure AI in Settings")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
        }
    }
}

struct TestButton: View {
    @State private var isTesting = false

    var body: some View {
        Button(isTesting ? "Testing..." : "Test Check") {
            Task {
                isTesting = true
                do {
                    let result = try await AIPipeline.shared.analyze()
                    print("✅ 测试完成: \(result.state.rawValue), 置信度: \(String(format: "%.2f", result.confidence))")
                } catch {
                    print("❌ 测试失败: \(error.localizedDescription)")
                }
                isTesting = false
            }
        }
        .disabled(isTesting)
        .buttonStyle(.bordered)
    }
}

struct StatisticsSection: View {
    @StateObject private var store = DetectionStore.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Today's Stats")
                .font(.caption)
                .foregroundColor(.secondary)

            HStack {
                StatItem(label: "Focused", value: "\(store.todayStats.focusedCount)")
                StatItem(label: "Distracted", value: "\(store.todayStats.distractedCount)")
                StatItem(label: "Away", value: "\(store.todayStats.awayCount)")
            }

            Text("Checks: \(store.todayStats.totalChecks)  Focus: \(Int(store.todayStats.focusRate * 100))%  Avg: \(store.todayStats.avgResponseTimeMs)ms")
                .font(.caption2)
                .foregroundColor(.secondary)

            Text("L0: \(store.todayStats.level0Count)  L1: \(store.todayStats.level1Count)  Conf: \(String(format: "%.0f", store.todayStats.avgConfidence * 100))%")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

struct StatItem: View {
    let label: String
    let value: String

    var body: some View {
        VStack {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
