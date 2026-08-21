import Foundation
import Darwin

/// Local Unix-socket listener. The Cursor hook script writes one JSON line per event.
final class HookEventServer: @unchecked Sendable {
    var onEvent: (@MainActor (CursorEvent) -> Void)?

    private var listenFD: Int32 = -1
    private var source: DispatchSourceRead?
    private let queue = DispatchQueue(label: "app.cursornotch.events")
    private let socketURL: URL

    init(socketURL: URL = CursorHookManager().socketURL) {
        self.socketURL = socketURL
    }

    func start() {
        queue.async { [weak self] in
            self?.bindAndListen()
        }
    }

    func stop() {
        queue.sync {
            source?.cancel()
            source = nil
            if listenFD >= 0 {
                close(listenFD)
                listenFD = -1
            }
        }
    }

    private func bindAndListen() {
        let directory = socketURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        unlink(socketURL.path)

        listenFD = socket(AF_UNIX, SOCK_STREAM, 0)
        guard listenFD >= 0 else { return }

        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        let pathBytes = socketURL.path.utf8CString
        guard pathBytes.count <= MemoryLayout.size(ofValue: addr.sun_path) else {
            close(listenFD)
            listenFD = -1
            return
        }
        withUnsafeMutablePointer(to: &addr.sun_path) { pointer in
            pointer.withMemoryRebound(to: CChar.self, capacity: pathBytes.count) { cPath in
                for (index, byte) in pathBytes.enumerated() {
                    cPath[index] = byte
                }
            }
        }

        let bindResult = withUnsafePointer(to: &addr) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPointer in
                bind(listenFD, sockaddrPointer, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        guard bindResult == 0, listen(listenFD, 8) == 0 else {
            close(listenFD)
            listenFD = -1
            return
        }
        chmod(socketURL.path, 0o600)

        let fd = listenFD
        let readSource = DispatchSource.makeReadSource(fileDescriptor: fd, queue: queue)
        readSource.setEventHandler { [weak self] in
            self?.acceptConnection()
        }
        readSource.setCancelHandler { [weak self] in
            guard let self, self.listenFD >= 0 else { return }
            close(self.listenFD)
            self.listenFD = -1
        }
        source = readSource
        readSource.resume()
    }

    private func acceptConnection() {
        let client = accept(listenFD, nil, nil)
        guard client >= 0 else { return }
        defer { close(client) }

        var buffer = [UInt8](repeating: 0, count: 16_384)
        let count = read(client, &buffer, buffer.count)
        guard count > 0 else { return }
        let data = Data(buffer.prefix(Int(count)))
        for line in data.split(separator: 0x0A) where !line.isEmpty {
            guard let payload = try? JSONDecoder().decode(HookPayload.self, from: Data(line)) else {
                continue
            }
            let event = CursorEvent.fromHookPayload(payload)
            Task { @MainActor [onEvent] in
                onEvent?(event)
            }
        }
    }
}
