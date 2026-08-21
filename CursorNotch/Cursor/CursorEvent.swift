import Foundation

enum CursorEventKind: String, Sendable {
    case started
    case activity
    case finished
    case failed
    case ignored
}

struct CursorEvent: Sendable, Equatable {
    var kind: CursorEventKind
    var conversationID: String
    var status: String

    init(kind: CursorEventKind, conversationID: String, status: String = "") {
        self.kind = kind
        self.conversationID = conversationID.isEmpty ? "unknown" : conversationID
        self.status = status
    }

    static func fromHookPayload(_ payload: HookPayload) -> CursorEvent {
        CursorEvent(
            kind: kind(for: payload.hookEventName, status: payload.status),
            conversationID: payload.conversationID,
            status: payload.status
        )
    }

    private static func kind(for rawName: String, status: String) -> CursorEventKind {
        let name = rawName
            .replacingOccurrences(of: "_", with: "")
            .replacingOccurrences(of: "-", with: "")
            .lowercased()

        switch name {
        case "beforesubmitprompt":
            return .started
        case "pretooluse", "posttooluse", "posttoolusefailure",
             "beforeshellexecution", "aftershellexecution",
             "beforemcpexecution", "aftermcpexecution",
             "beforereadfile", "afterfileedit":
            return .activity
        case "stop", "sessionend":
            if ["error", "aborted", "failed", "failure"].contains(status.lowercased()) {
                return .failed
            }
            return .finished
        default:
            return .ignored
        }
    }
}

struct HookPayload: Decodable, Sendable {
    var hookEventName: String
    var conversationID: String
    var generationID: String
    var status: String

    enum CodingKeys: String, CodingKey {
        case hookEventName = "hook_event_name"
        case conversationID = "conversation_id"
        case generationID = "generation_id"
        case status
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        hookEventName = try container.decodeIfPresent(String.self, forKey: .hookEventName) ?? ""
        conversationID = try container.decodeIfPresent(String.self, forKey: .conversationID) ?? ""
        generationID = try container.decodeIfPresent(String.self, forKey: .generationID) ?? ""
        status = try container.decodeIfPresent(String.self, forKey: .status) ?? ""
    }
}
