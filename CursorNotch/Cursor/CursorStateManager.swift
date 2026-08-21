import Foundation

enum NotchState: Equatable {
    case idle
    case working
    case completed
}

/// Turns Cursor hook events into a single notch state.
///
/// Cursor's `stop` hook can fire after an intermediate model turn, not only
/// at true task end. A short debounce waits for the next prompt/tool event
/// before leaving WORKING. Multiple conversations stay in WORKING until
/// every tracked task has stopped.
@MainActor
final class CursorStateManager {
    private(set) var state: NotchState = .idle
    private var activeIDs: Set<String> = []
    private var pendingFinish: Task<Void, Never>?
    var onChange: ((NotchState) -> Void)?

    func apply(_ event: CursorEvent) {
        switch event.kind {
        case .ignored:
            return
        case .started, .activity:
            pendingFinish?.cancel()
            pendingFinish = nil
            activeIDs.insert(event.conversationID)
            setState(.working)
        case .finished, .failed:
            activeIDs.remove(event.conversationID)
            if activeIDs.isEmpty {
                scheduleFinish()
            } else {
                setState(.working)
            }
        }
    }

    func resetToIdle() {
        pendingFinish?.cancel()
        pendingFinish = nil
        activeIDs.removeAll()
        setState(.idle)
    }

    func forceWorking() {
        pendingFinish?.cancel()
        pendingFinish = nil
        setState(.working)
    }

    func forceCompleted() {
        pendingFinish?.cancel()
        pendingFinish = nil
        activeIDs.removeAll()
        setState(.completed)
    }

    private func scheduleFinish() {
        pendingFinish?.cancel()
        pendingFinish = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(700))
            guard let self, !Task.isCancelled else { return }
            guard self.activeIDs.isEmpty else { return }
            self.setState(.completed)
        }
    }

    private func setState(_ newState: NotchState) {
        guard state != newState else { return }
        state = newState
        onChange?(newState)
    }
}
