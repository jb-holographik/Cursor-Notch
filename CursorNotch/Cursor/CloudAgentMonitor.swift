import Foundation
import SQLite3

/// Watches Cursor's local Cloud Agent cache. User hooks never run on the
/// remote VM, but the desktop app writes `BackgroundComposerStatus` into
/// `state.vscdb` while Cursor is open.
final class CloudAgentMonitor: @unchecked Sendable {
    var onEvent: (@MainActor (CursorEvent) -> Void)?

    private let queue = DispatchQueue(label: "app.cursornotch.cloud-agents")
    private var timer: DispatchSourceTimer?
    private var knownActive: Set<String> = []
    private var didPrime = false
    private let databaseURL: URL

    /// `aiserver.v1.BackgroundComposerStatus`
    private enum Status: Int {
        case unspecified = 0
        case running = 1
        case finished = 2
        case error = 3
        case creating = 4
        case expired = 5
    }

    init(
        databaseURL: URL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Cursor/User/globalStorage/state.vscdb")
    ) {
        self.databaseURL = databaseURL
    }

    func start() {
        queue.async { [weak self] in
            self?.tick()
            self?.schedule()
        }
    }

    func stop() {
        queue.sync {
            timer?.cancel()
            timer = nil
        }
    }

    private func schedule() {
        let source = DispatchSource.makeTimerSource(queue: queue)
        source.schedule(deadline: .now() + 1, repeating: 1, leeway: .milliseconds(200))
        source.setEventHandler { [weak self] in
            self?.tick()
        }
        timer = source
        source.resume()
    }

    private func tick() {
        let agents = readAgents()
        let active = Set(agents.filter(\.isActive).map(\.conversationID))

        if !didPrime {
            didPrime = true
            knownActive = active
            for id in active {
                emit(CursorEvent(kind: .started, conversationID: id))
            }
            return
        }

        for id in active where !knownActive.contains(id) {
            emit(CursorEvent(kind: .started, conversationID: id))
        }
        for id in knownActive where !active.contains(id) {
            let agent = agents.first { $0.conversationID == id }
            let failed = agent?.isKilled == true || agent?.status == .error
            emit(
                CursorEvent(
                    kind: failed ? .failed : .finished,
                    conversationID: id,
                    status: failed ? "error" : ""
                )
            )
        }
        knownActive = active
    }

    private func emit(_ event: CursorEvent) {
        Task { @MainActor [onEvent] in
            onEvent?(event)
        }
    }

    private func readAgents() -> [CachedAgent] {
        guard FileManager.default.fileExists(atPath: databaseURL.path) else { return [] }

        var components = URLComponents()
        components.scheme = "file"
        components.path = databaseURL.path
        components.query = "mode=ro"
        guard let uri = components.string else { return [] }

        var db: OpaquePointer?
        let flags = SQLITE_OPEN_READONLY | SQLITE_OPEN_URI | SQLITE_OPEN_NOMUTEX
        guard sqlite3_open_v2(uri, &db, flags, nil) == SQLITE_OK, let db else {
            if db != nil { sqlite3_close(db) }
            return []
        }
        defer { sqlite3_close(db) }
        sqlite3_busy_timeout(db, 80)

        let sql = "SELECT value FROM ItemTable WHERE key LIKE 'cloudAgentRepository.agents.%'"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
            return []
        }
        defer { sqlite3_finalize(statement) }

        var blobs: [Data] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            guard let bytes = sqlite3_column_text(statement, 0) else { continue }
            blobs.append(Data(bytes: bytes, count: Int(sqlite3_column_bytes(statement, 0))))
        }

        return blobs.flatMap { decodeAgents(from: $0) }
    }

    private func decodeAgents(from data: Data) -> [CachedAgent] {
        guard
            let raw = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        else { return [] }
        return raw.compactMap { item in
            guard let bcId = item["bcId"] as? String, !bcId.isEmpty else { return nil }
            return CachedAgent(
                conversationID: "cloud:\(bcId)",
                status: Status(rawValue: intValue(item["status"])) ?? .unspecified,
                isKilled: boolValue(item["isKilled"])
            )
        }
    }

    private func intValue(_ value: Any?) -> Int {
        if let number = value as? NSNumber { return number.intValue }
        if let number = value as? Int { return number }
        return 0
    }

    private func boolValue(_ value: Any?) -> Bool {
        if let flag = value as? Bool { return flag }
        if let number = value as? NSNumber { return number.boolValue }
        return false
    }

    private struct CachedAgent {
        let conversationID: String
        let status: Status
        let isKilled: Bool

        var isActive: Bool {
            !isKilled && (status == .running || status == .creating)
        }
    }
}
