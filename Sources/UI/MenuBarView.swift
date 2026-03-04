import SwiftUI
import AppKit

struct MenuBarView: View {
    @StateObject private var stateMachine = StateMachine.shared

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    FGTheme.bgTop,
                    FGTheme.bgBottom
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 10) {
                HeaderSection(state: stateMachine.currentState)
                ActionSection()
                StatsSection()
                FooterSection()
            }
            .padding(12)
        }
        .frame(width: 320)
        .preferredColorScheme(.dark)
    }
}

private struct HeaderSection: View {
    let state: MonitoringState
    @StateObject private var engine = MonitorEngine.shared

    var body: some View {
        CardContainer {
            HStack(alignment: .center, spacing: 10) {
                Circle()
                    .fill(stateColor)
                    .frame(width: 12, height: 12)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(FGTheme.primaryText)
                    if let nextCheck = engine.nextCheckAt {
                        Text("Next check \(nextCheck, style: .time)")
                            .font(.system(size: 11, weight: .regular, design: .rounded))
                            .foregroundColor(FGTheme.secondaryText)
                    } else {
                        Text("No schedule")
                            .font(.system(size: 11, weight: .regular, design: .rounded))
                            .foregroundColor(FGTheme.secondaryText)
                    }
                }

                Spacer()

                Text(stateTag)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(stateColor.opacity(0.16))
                    .foregroundColor(stateColor)
                    .clipShape(Capsule())
            }
        }
    }

    private var title: String {
        switch state {
        case .normal: return "Monitoring"
        case .alert(let level): return level == .first ? "Alert" : "Intervention"
        case .deepFocus: return "Deep Focus"
        case .paused: return "Paused"
        }
    }

    private var stateTag: String {
        switch state {
        case .normal: return "NORMAL"
        case .alert(let level): return level == .first ? "ALERT-L1" : "ALERT-L2"
        case .deepFocus: return "FLOW"
        case .paused: return "PAUSED"
        }
    }

    private var stateColor: Color {
        switch state {
        case .normal: return Color(red: 0.09, green: 0.57, blue: 0.29)
        case .alert(let level): return level == .first ? Color.orange : Color.red
        case .deepFocus: return Color.blue
        case .paused: return Color.gray
        }
    }
}

private struct ActionSection: View {
    @StateObject private var engine = MonitorEngine.shared
    @StateObject private var settings = Settings.shared

    var body: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 8) {
                Text("Controls")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(FGTheme.secondaryText)

                HStack(spacing: 8) {
                    if engine.isRunning {
                        Button("Pause") { engine.pause() }
                            .buttonStyle(ActionButtonStyle(accent: .orange))
                    } else if engine.isPaused {
                        Button("Resume") { engine.resume() }
                            .buttonStyle(ActionButtonStyle(accent: .blue))
                    } else {
                        Button("Start") { engine.start() }
                            .buttonStyle(ActionButtonStyle(accent: .green))
                            .disabled(!settings.isConfigured)
                    }

                    Button("Stop") { engine.stop() }
                        .buttonStyle(ActionButtonStyle(accent: .red))
                        .disabled(!engine.isRunning && !engine.isPaused)
                }

                TestButton()

                if !settings.isConfigured {
                    Text("Configure AI provider in Settings.")
                        .font(.system(size: 11, weight: .regular, design: .rounded))
                        .foregroundColor(FGTheme.warningText)
                }
            }
        }
    }
}

struct TestButton: View {
    @State private var isTesting = false

    var body: some View {
        Button(isTesting ? "Running test..." : "Run instant check") {
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
        .buttonStyle(ActionButtonStyle(accent: .black))
        .disabled(isTesting)
    }
}

private struct StatsSection: View {
    @StateObject private var store = DetectionStore.shared

    var body: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 8) {
                Text("Today")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(FGTheme.secondaryText)

                HStack(spacing: 8) {
                    StatCell(label: "Focused", value: "\(store.todayStats.focusedCount)")
                    StatCell(label: "Distracted", value: "\(store.todayStats.distractedCount)")
                    StatCell(label: "Away", value: "\(store.todayStats.awayCount)")
                }

                Text("Checks \(store.todayStats.totalChecks) | Focus \(Int(store.todayStats.focusRate * 100))% | Avg \(store.todayStats.avgResponseTimeMs)ms")
                    .font(.system(size: 11, weight: .regular, design: .rounded))
                    .foregroundColor(FGTheme.secondaryText)

                Text("Pipeline L0 \(store.todayStats.level0Count) / L1 \(store.todayStats.level1Count) | Confidence \(String(format: "%.0f", store.todayStats.avgConfidence * 100))%")
                    .font(.system(size: 11, weight: .regular, design: .rounded))
                    .foregroundColor(FGTheme.secondaryText)
            }
        }
    }
}

private struct FooterSection: View {
    var body: some View {
        HStack(spacing: 8) {
            Button("Settings") {
                SettingsWindowController.shared.showSettings()
            }
            .buttonStyle(ActionButtonStyle(accent: .blue))

            Button("Quit") {
                NSApp.terminate(nil)
            }
            .buttonStyle(ActionButtonStyle(accent: .gray))
        }
    }
}

private struct CardContainer<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(FGTheme.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(FGTheme.cardBorder, lineWidth: 1)
            )
    }
}

private struct StatCell: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(FGTheme.primaryText)
            Text(label)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundColor(FGTheme.secondaryText)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(FGTheme.cardInner)
        )
    }
}

private struct ActionButtonStyle: ButtonStyle {
    let accent: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(accent.opacity(configuration.isPressed ? 0.75 : 0.9))
            )
            .foregroundColor(.white)
            .opacity(configuration.isPressed ? 0.92 : 1.0)
    }
}

private enum FGTheme {
    static let bgTop = Color(red: 0.08, green: 0.10, blue: 0.14)
    static let bgBottom = Color(red: 0.12, green: 0.13, blue: 0.17)
    static let card = Color(red: 0.16, green: 0.18, blue: 0.23)
    static let cardInner = Color(red: 0.20, green: 0.22, blue: 0.28)
    static let cardBorder = Color.white.opacity(0.10)
    static let primaryText = Color(red: 0.96, green: 0.97, blue: 0.99)
    static let secondaryText = Color(red: 0.74, green: 0.78, blue: 0.86)
    static let warningText = Color(red: 1.0, green: 0.72, blue: 0.35)
}
