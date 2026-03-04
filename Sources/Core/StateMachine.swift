import SwiftUI

enum MonitoringState: Equatable {
    case normal
    case alert(level: AlertLevel)
    case deepFocus
    case paused
    
    enum AlertLevel {
        case first
        case second
    }
}

@MainActor
class StateMachine: ObservableObject {
    static let shared = StateMachine()
    
    @Published private(set) var currentState: MonitoringState = .normal
    @Published private(set) var consecutiveFocusCount: Int = 0
    @Published private(set) var consecutiveDistractedCount: Int = 0
    
    private init() {}
    
    func transition(to newState: MonitoringState) {
        guard currentState != newState else { return }
        
        let oldStateDesc = stateDescription(currentState)
        let newStateDesc = stateDescription(newState)
        print("[StateMachine] 🔄 状态转换: \(oldStateDesc) → \(newStateDesc)")
        
        updateConsecutiveCounts(from: currentState, to: newState)
        currentState = newState
        
        NotificationCenter.default.post(
            name: .stateChanged,
            object: nil,
            userInfo: ["state": newState]
        )
    }
    
    private func stateDescription(_ state: MonitoringState) -> String {
        switch state {
        case .normal: return "正常"
        case .alert(let level): return level == .first ? "警觉(一级)" : "干预(二级)"
        case .deepFocus: return "深度专注"
        case .paused: return "暂停"
        }
    }
    
    func reportDetectionResult(_ result: DetectionResult) {
        print("[StateMachine] 📥 收到检测结果: \(result.state.rawValue) (连续专注:\(consecutiveFocusCount), 连续分心:\(consecutiveDistractedCount))")
        
        switch result.state {
        case .focused:
            consecutiveFocusCount += 1
            consecutiveDistractedCount = 0
            print("[StateMachine] 🎯 专注检测 #\(consecutiveFocusCount)")
            
            if consecutiveFocusCount >= 3 && currentState != .deepFocus {
                print("[StateMachine] 🌟 连续3次专注，进入深度专注模式")
                transition(to: .deepFocus)
            } else if case .alert = currentState {
                print("[StateMachine] ✓ 从警觉状态恢复")
                transition(to: .normal)
            }
            
        case .distracted:
            consecutiveDistractedCount += 1
            consecutiveFocusCount = 0
            print("[StateMachine] ⚠️ 分心检测 #\(consecutiveDistractedCount)")
            
            switch currentState {
            case .normal, .deepFocus:
                print("[StateMachine] 🔔 检测到分心，进入警觉状态")
                transition(to: .alert(level: .first))
            case .alert(let level):
                if level == .first && consecutiveDistractedCount >= 2 {
                    print("[StateMachine] 🚨 连续分心，升级到干预状态")
                    transition(to: .alert(level: .second))
                }
            case .paused:
                break
            }
            
        case .away:
            print("[StateMachine] 👤 检测到用户离开")
            consecutiveFocusCount = 0
            consecutiveDistractedCount = 0
            if currentState == .deepFocus {
                transition(to: .normal)
            }
        }
    }
    
    func pause() {
        transition(to: .paused)
    }
    
    func resume() {
        consecutiveFocusCount = 0
        consecutiveDistractedCount = 0
        transition(to: .normal)
    }
    
    private func updateConsecutiveCounts(from oldState: MonitoringState, to newState: MonitoringState) {
        if case .paused = newState {
            return
        }
        if case .paused = oldState, case .normal = newState {
            consecutiveFocusCount = 0
            consecutiveDistractedCount = 0
        }
    }
}

struct DetectionResult: Sendable {
    let state: AttentionState
    let confidence: Double
    let source: AISource
    
    enum AttentionState: String, Sendable {
        case focused
        case distracted
        case away
    }
    
    enum AISource: Sendable {
        case level0
        case level1
    }
    
    enum DistractionType: String, Sendable {
        case phone
        case lookingAway
        case drowsy
        case other
    }
}

extension Notification.Name {
    static let stateChanged = Notification.Name("stateChanged")
}
