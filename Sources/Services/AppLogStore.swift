import Foundation

struct AppLogEntry: Codable, Identifiable {
    enum Level: String, Codable {
        case info
        case warning
        case error
    }

    let id: UUID
    let timestamp: Date
    let level: Level
    let category: String
    let message: String

    init(level: Level, category: String, message: String) {
        self.id = UUID()
        self.timestamp = Date()
        self.level = level
        self.category = category
        self.message = message
    }
}

@MainActor
final class AppLogStore: ObservableObject {
    static let shared = AppLogStore()

    @Published private(set) var entries: [AppLogEntry] = []

    private let maxInMemoryEntries = 300
    private let logFileURL: URL

    private init() {
        let appSupport = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("FocusGuard", isDirectory: true)

        try? FileManager.default.createDirectory(at: appSupport, withIntermediateDirectories: true)
        self.logFileURL = appSupport.appendingPathComponent("app.log")
        loadRecentEntries()
    }

    func log(level: AppLogEntry.Level, category: String, message: String) {
        let entry = AppLogEntry(level: level, category: category, message: message)
        entries.append(entry)
        if entries.count > maxInMemoryEntries {
            entries.removeFirst(entries.count - maxInMemoryEntries)
        }

        let timestamp = ISO8601DateFormatter().string(from: entry.timestamp)
        let line = "[\(timestamp)] [\(entry.level.rawValue.uppercased())] [\(entry.category)] \(entry.message)\n"
        if let data = line.data(using: .utf8) {
            appendToLogFile(data: data)
        }
    }

    func clear() {
        entries.removeAll()
        try? FileManager.default.removeItem(at: logFileURL)
    }

    func reload() {
        loadRecentEntries()
    }

    private func appendToLogFile(data: Data) {
        if !FileManager.default.fileExists(atPath: logFileURL.path) {
            FileManager.default.createFile(atPath: logFileURL.path, contents: data)
            return
        }

        do {
            let handle = try FileHandle(forWritingTo: logFileURL)
            defer { try? handle.close() }
            try handle.seekToEnd()
            try handle.write(contentsOf: data)
        } catch {
            print("[AppLogStore] 写入日志失败: \(error.localizedDescription)")
        }
    }

    private func loadRecentEntries() {
        guard let content = try? String(contentsOf: logFileURL, encoding: .utf8) else {
            entries = []
            return
        }

        let lines = content.split(separator: "\n")
        let recent = lines.suffix(maxInMemoryEntries)

        let parsed = recent.map { line in
            let text = String(line)
            return AppLogEntry(level: inferLevel(from: text), category: inferCategory(from: text), message: text)
        }
        entries = parsed
    }

    private func inferLevel(from line: String) -> AppLogEntry.Level {
        if line.contains("[ERROR]") { return .error }
        if line.contains("[WARNING]") { return .warning }
        return .info
    }

    private func inferCategory(from line: String) -> String {
        guard let categoryStart = line.range(of: "] [", options: .backwards)?.upperBound,
              let categoryEnd = line[categoryStart...].firstIndex(of: "]") else {
            return "General"
        }
        return String(line[categoryStart..<categoryEnd])
    }
}
