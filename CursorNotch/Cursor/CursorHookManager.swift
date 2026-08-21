import Foundation

/// Installs an observer-only Cursor user hook.
/// Cursor's supported path is `~/.cursor/hooks.json` (see cursor.com/docs/hooks).
/// Existing entries are preserved; only this app's relay command is added or updated.
struct CursorHookManager: Sendable {
    static let hookFileName = "cursor-notch-hook.py"
    static let marker = "cursor-notch-hook"

    private let fileManager: FileManager
    private let homeDirectory: URL

    var isInstalled: Bool {
        guard let handlers = (try? readHooks())?["hooks"] as? [String: Any] else { return false }
        return Self.observedEvents.allSatisfy { event in
            let entries = handlers[event] as? [[String: Any]] ?? []
            return entries.contains { Self.isOwned($0) }
        }
    }

    init(
        fileManager: FileManager = .default,
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
    ) {
        self.fileManager = fileManager
        self.homeDirectory = homeDirectory
    }

    func refresh() {
        _ = isInstalled
    }

    func installIfNeeded() throws {
        try installHookScript()
        try mergeHookConfiguration()
    }

    var hooksURL: URL {
        homeDirectory.appendingPathComponent(".cursor/hooks.json")
    }

    var scriptURL: URL {
        supportDirectory.appendingPathComponent(Self.hookFileName)
    }

    var supportDirectory: URL {
        homeDirectory.appendingPathComponent("Library/Application Support/CursorNotch")
    }

    var socketURL: URL {
        supportDirectory.appendingPathComponent("cursor-notch.sock")
    }

    private static let observedEvents = [
        "beforeSubmitPrompt",
        "preToolUse",
        "postToolUse",
        "postToolUseFailure",
        "stop",
        "sessionEnd",
    ]

    private func installHookScript() throws {
        try fileManager.createDirectory(
            at: supportDirectory,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )

        guard let bundled = Bundle.main.url(forResource: "cursor-notch-hook", withExtension: "py") else {
            throw HookError.missingBundledScript
        }
        let data = try Data(contentsOf: bundled)
        if fileManager.fileExists(atPath: scriptURL.path) {
            let existing = try Data(contentsOf: scriptURL)
            if existing == data { return }
        }
        try data.write(to: scriptURL, options: .atomic)
        try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptURL.path)
    }

    private func mergeHookConfiguration() throws {
        var root = (try? readHooks()) ?? [:]
        if root["version"] == nil {
            root["version"] = 1
        }
        var hooks = root["hooks"] as? [String: Any] ?? [:]
        let command = scriptURL.path

        for event in Self.observedEvents {
            var entries = hooks[event] as? [[String: Any]] ?? []
            entries.removeAll { Self.isOwned($0) }
            var handler: [String: Any] = [
                "command": command,
                "timeout": 5,
            ]
            if event == "stop" || event == "sessionEnd" {
                handler["loop_limit"] = NSNull()
            }
            entries.append(handler)
            hooks[event] = entries
        }

        root["hooks"] = hooks
        let data = try JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys])
        try fileManager.createDirectory(
            at: hooksURL.deletingLastPathComponent(),
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        try data.write(to: hooksURL, options: .atomic)
    }

    private func readHooks() throws -> [String: Any] {
        guard fileManager.fileExists(atPath: hooksURL.path) else { return [:] }
        let data = try Data(contentsOf: hooksURL)
        guard !data.isEmpty else { return [:] }
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw HookError.invalidHooksFile(hooksURL.path)
        }
        return root
    }

    private static func isOwned(_ handler: [String: Any]) -> Bool {
        (handler["command"] as? String)?.contains(marker) == true
    }
}

enum HookError: LocalizedError {
    case missingBundledScript
    case invalidHooksFile(String)

    var errorDescription: String? {
        switch self {
        case .missingBundledScript:
            "The bundled Cursor hook script is missing from the app bundle."
        case let .invalidHooksFile(path):
            "\(path) exists but is not a JSON object, so Cursor Notch did not modify it."
        }
    }
}
