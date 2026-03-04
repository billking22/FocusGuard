import Foundation
import SQLite

@MainActor
class DetectionStore: ObservableObject {
    static let shared = DetectionStore()
    
    private var db: Connection?
    private let detections: Table
    
    private let id = Expression<String>("id")
    private let timestamp = Expression<Double>("timestamp")
    private let state = Expression<String>("state")
    private let distractionType = Expression<String?>("distraction_type")
    private let confidence = Expression<Double>("confidence")
    private let aiSource = Expression<String>("ai_source")
    private let responseTimeMs = Expression<Int>("response_time_ms")
    
    @Published var todayStats: DayStatistics = DayStatistics()
    
    private init() {
        detections = Table("detections")
        setupDatabase()
        updateTodayStats()
    }
    
    private func setupDatabase() {
        do {
            let path = FileManager.default
                .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("FocusGuard")
            
            try FileManager.default.createDirectory(at: path, withIntermediateDirectories: true)
            
            let dbPath = path.appendingPathComponent("detections.db").path
            db = try Connection(dbPath)
            
            try db?.run(detections.create(ifNotExists: true) { t in
                t.column(id, primaryKey: true)
                t.column(timestamp)
                t.column(state)
                t.column(distractionType)
                t.column(confidence)
                t.column(aiSource)
                t.column(responseTimeMs)
            })
            
            try db?.run(detections.createIndex(timestamp, ifNotExists: true))
            
        } catch {
            print("Database setup error: \(error)")
        }
    }
    
    func insert(_ record: DetectionRecord) {
        guard let db = db else { return }
        
        do {
            let insert = detections.insert(
                id <- record.id.uuidString,
                timestamp <- record.timestamp.timeIntervalSince1970,
                state <- record.state.rawValue,
                distractionType <- record.distractionType?.rawValue,
                confidence <- record.confidence,
                aiSource <- record.source == .level0 ? "L0" : "L1",
                responseTimeMs <- record.responseTimeMs
            )
            try db.run(insert)
            updateTodayStats()
        } catch {
            print("Insert error: \(error)")
        }
    }
    
    func updateTodayStats() {
        guard let db = db else { return }
        
        do {
            let calendar = Calendar.current
            let startOfDay = calendar.startOfDay(for: Date())
            let startTimestamp = startOfDay.timeIntervalSince1970
            
            let todayQuery = detections.filter(timestamp >= startTimestamp)
            
            var focused = 0
            var distracted = 0
            var away = 0
            var level0 = 0
            var level1 = 0
            var confidenceSum = 0.0
            var responseTimeSum = 0

            for row in try db.prepare(todayQuery) {
                switch row[state] {
                case "focused": focused += 1
                case "distracted": distracted += 1
                case "away": away += 1
                default: break
                }

                if row[aiSource] == "L0" {
                    level0 += 1
                } else if row[aiSource] == "L1" {
                    level1 += 1
                }

                confidenceSum += row[confidence]
                responseTimeSum += row[responseTimeMs]
            }

            let total = focused + distracted + away

            todayStats = DayStatistics(
                focusedCount: focused,
                distractedCount: distracted,
                awayCount: away,
                totalChecks: total,
                level0Count: level0,
                level1Count: level1,
                avgConfidence: total > 0 ? confidenceSum / Double(total) : 0,
                avgResponseTimeMs: total > 0 ? Int(Double(responseTimeSum) / Double(total)) : 0
            )
            
        } catch {
            print("Stats error: \(error)")
        }
    }
    
    func cleanupOldData(olderThan days: Int) {
        guard let db = db else { return }
        
        do {
            let cutoff = Date().addingTimeInterval(-Double(days) * 24 * 60 * 60)
            let oldRecords = detections.filter(timestamp < cutoff.timeIntervalSince1970)
            try db.run(oldRecords.delete())
        } catch {
            print("Cleanup error: \(error)")
        }
    }
}

struct DetectionRecord {
    let id: UUID
    let timestamp: Date
    let state: DetectionResult.AttentionState
    let distractionType: DetectionResult.DistractionType?
    let confidence: Double
    let source: DetectionResult.AISource
    let responseTimeMs: Int
    
    init(
        state: DetectionResult.AttentionState,
        confidence: Double,
        source: DetectionResult.AISource,
        responseTimeMs: Int,
        distractionType: DetectionResult.DistractionType? = nil
    ) {
        self.id = UUID()
        self.timestamp = Date()
        self.state = state
        self.confidence = confidence
        self.source = source
        self.responseTimeMs = responseTimeMs
        self.distractionType = distractionType
    }
}

struct DayStatistics {
    let focusedCount: Int
    let distractedCount: Int
    let awayCount: Int
    let totalChecks: Int
    let level0Count: Int
    let level1Count: Int
    let avgConfidence: Double
    let avgResponseTimeMs: Int
    
    init(
        focusedCount: Int = 0,
        distractedCount: Int = 0,
        awayCount: Int = 0,
        totalChecks: Int = 0,
        level0Count: Int = 0,
        level1Count: Int = 0,
        avgConfidence: Double = 0,
        avgResponseTimeMs: Int = 0
    ) {
        self.focusedCount = focusedCount
        self.distractedCount = distractedCount
        self.awayCount = awayCount
        self.totalChecks = totalChecks
        self.level0Count = level0Count
        self.level1Count = level1Count
        self.avgConfidence = avgConfidence
        self.avgResponseTimeMs = avgResponseTimeMs
    }
    
    var focusRate: Double {
        guard totalChecks > 0 else { return 0 }
        return Double(focusedCount) / Double(totalChecks)
    }
    
    var distractionRate: Double {
        guard totalChecks > 0 else { return 0 }
        return Double(distractedCount) / Double(totalChecks)
    }
}
