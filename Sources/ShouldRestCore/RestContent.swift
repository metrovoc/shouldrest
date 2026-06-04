import Foundation

public struct RestIdea: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var kind: RestKind
    public var title: String
    public var body: String
    public var isEnabled: Bool

    public init(id: String, kind: RestKind, title: String, body: String, isEnabled: Bool = true) {
        self.id = id
        self.kind = kind
        self.title = title
        self.body = body
        self.isEnabled = isEnabled
    }
}

public enum BuiltInRestIdeas {
    public static let eyeGate = [
        RestIdea(
            id: "eye-gate-look-away",
            kind: .eyeGate,
            title: "Look far away",
            body: "Relax your focus. Blink slowly and keep your eyes off the screen until the timer ends."
        )
    ]

    public static let bodyBreak = [
        RestIdea(
            id: "body-stand-breathe",
            kind: .bodyBreak,
            title: "Stand and breathe",
            body: "Stand up, relax your shoulders, and take slow breaths."
        ),
        RestIdea(
            id: "body-neck-release",
            kind: .bodyBreak,
            title: "Release your neck",
            body: "Gently turn your head left and right, then look forward."
        ),
        RestIdea(
            id: "body-wrist-reset",
            kind: .bodyBreak,
            title: "Reset wrists",
            body: "Open your hands, rotate your wrists, and relax your grip."
        ),
        RestIdea(
            id: "body-walk",
            kind: .bodyBreak,
            title: "Walk briefly",
            body: "Step away from the desk and move around the room."
        )
    ]
}

public struct ContentLibrarySettings: Codable, Equatable, Sendable {
    public var useBuiltInIdeas: Bool
    public var customBodyBreakIdeas: [RestIdea]
    public var localImagePaths: [String]

    public init(useBuiltInIdeas: Bool, customBodyBreakIdeas: [RestIdea], localImagePaths: [String]) {
        self.useBuiltInIdeas = useBuiltInIdeas
        self.customBodyBreakIdeas = customBodyBreakIdeas
        self.localImagePaths = localImagePaths
    }

    public static let defaults = ContentLibrarySettings(
        useBuiltInIdeas: true,
        customBodyBreakIdeas: [],
        localImagePaths: []
    )

    public func ideas(for kind: RestKind) -> [RestIdea] {
        let builtIns: [RestIdea]
        switch kind {
        case .eyeGate:
            builtIns = useBuiltInIdeas ? BuiltInRestIdeas.eyeGate : []
        case .bodyBreak:
            builtIns = useBuiltInIdeas ? BuiltInRestIdeas.bodyBreak : []
        }

        return (builtIns + customBodyBreakIdeas.filter { $0.kind == kind }).filter(\.isEnabled)
    }
}
