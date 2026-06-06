import ShouldRestCore

struct AutomationStartRequest: Equatable {
    var kind: RestKind
    var bodyBreakIdea: RestIdea?

    init(kind: RestKind, bodyBreakIdea: RestIdea? = nil) {
        self.kind = kind
        self.bodyBreakIdea = kind == .bodyBreak ? bodyBreakIdea : nil
    }
}

struct PendingAutomationStartRequests: Equatable {
    private(set) var requests: [AutomationStartRequest] = []

    var next: AutomationStartRequest? {
        requests.first
    }

    mutating func enqueue(_ request: AutomationStartRequest) {
        if let index = requests.firstIndex(where: { $0.kind == request.kind }) {
            requests[index] = request
        } else {
            requests.append(request)
        }
    }

    mutating func remove(_ request: AutomationStartRequest) {
        requests.removeAll { $0.kind == request.kind }
    }

    mutating func clearAll() {
        requests.removeAll()
    }
}

enum AutomationStartRetryDecision: Equatable {
    case satisfied
    case keepPending
    case discard
}

enum AutomationStartRetryPolicy {
    static func decision(for result: RestEngineResult) -> AutomationStartRetryDecision {
        switch result {
        case .started:
            return .satisfied
        case .denied(.alreadyActive), .denied(.alreadyPaused):
            return .keepPending
        default:
            return .discard
        }
    }
}
