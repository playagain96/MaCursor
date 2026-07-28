public struct Slot: Hashable, Sendable {
    public let identifier: String
    public let displayName: String

    public init(identifier: String, displayName: String) {
        self.identifier = identifier
        self.displayName = displayName
    }
}

public enum Slots {
    public static let all: [Slot] = [
        Slot(identifier: "com.apple.coregraphics.Arrow", displayName: "Arrow"),
        Slot(identifier: "com.apple.coregraphics.IBeam", displayName: "IBeam"),
        Slot(identifier: "com.apple.coregraphics.IBeamXOR", displayName: "IBeamXOR"),
        Slot(identifier: "com.apple.coregraphics.Alias", displayName: "Alias"),
        Slot(identifier: "com.apple.coregraphics.Copy", displayName: "Copy"),
        Slot(identifier: "com.apple.coregraphics.Move", displayName: "Move"),
        Slot(identifier: "com.apple.coregraphics.ArrowCtx", displayName: "Ctx Arrow"),
        Slot(identifier: "com.apple.coregraphics.Wait", displayName: "Wait"),
        Slot(identifier: "com.apple.coregraphics.Empty", displayName: "Empty"),
        Slot(identifier: "com.apple.cursor.0", displayName: "Arrow"),
        Slot(identifier: "com.apple.cursor.1", displayName: "IBeam"),
        Slot(identifier: "com.apple.cursor.2", displayName: "Link"),
        Slot(identifier: "com.apple.cursor.3", displayName: "Forbidden"),
        Slot(identifier: "com.apple.cursor.4", displayName: "Busy"),
        Slot(identifier: "com.apple.cursor.5", displayName: "Copy Drag"),
        Slot(identifier: "com.apple.cursor.7", displayName: "Crosshair"),
        Slot(identifier: "com.apple.cursor.8", displayName: "Crosshair 2"),
        Slot(identifier: "com.apple.cursor.9", displayName: "Camera 2"),
        Slot(identifier: "com.apple.cursor.10", displayName: "Camera"),
        Slot(identifier: "com.apple.cursor.11", displayName: "Closed"),
        Slot(identifier: "com.apple.cursor.12", displayName: "Open"),
        Slot(identifier: "com.apple.cursor.13", displayName: "Pointing"),
        Slot(identifier: "com.apple.cursor.14", displayName: "Counting Up"),
        Slot(identifier: "com.apple.cursor.15", displayName: "Counting Down"),
        Slot(identifier: "com.apple.cursor.16", displayName: "Counting Up/Down"),
        Slot(identifier: "com.apple.cursor.17", displayName: "Resize W"),
        Slot(identifier: "com.apple.cursor.18", displayName: "Resize E"),
        Slot(identifier: "com.apple.cursor.19", displayName: "Resize W-E"),
        Slot(identifier: "com.apple.cursor.20", displayName: "Cell XOR"),
        Slot(identifier: "com.apple.cursor.21", displayName: "Resize N"),
        Slot(identifier: "com.apple.cursor.22", displayName: "Resize S"),
        Slot(identifier: "com.apple.cursor.23", displayName: "Resize N-S"),
        Slot(identifier: "com.apple.cursor.24", displayName: "Ctx Menu"),
        Slot(identifier: "com.apple.cursor.25", displayName: "Poof"),
        Slot(identifier: "com.apple.cursor.26", displayName: "IBeam H."),
        Slot(identifier: "com.apple.cursor.27", displayName: "Window E"),
        Slot(identifier: "com.apple.cursor.28", displayName: "Window E-W"),
        Slot(identifier: "com.apple.cursor.29", displayName: "Window NE"),
        Slot(identifier: "com.apple.cursor.30", displayName: "Window NE-SW"),
        Slot(identifier: "com.apple.cursor.31", displayName: "Window N"),
        Slot(identifier: "com.apple.cursor.32", displayName: "Window N-S"),
        Slot(identifier: "com.apple.cursor.33", displayName: "Window NW"),
        Slot(identifier: "com.apple.cursor.34", displayName: "Window NW-SE"),
        Slot(identifier: "com.apple.cursor.35", displayName: "Window SE"),
        Slot(identifier: "com.apple.cursor.36", displayName: "Window S"),
        Slot(identifier: "com.apple.cursor.37", displayName: "Window SW"),
        Slot(identifier: "com.apple.cursor.38", displayName: "Window W"),
        Slot(identifier: "com.apple.cursor.39", displayName: "Resize Square"),
        Slot(identifier: "com.apple.cursor.40", displayName: "Help"),
        Slot(identifier: "com.apple.cursor.41", displayName: "Cell"),
        Slot(identifier: "com.apple.cursor.42", displayName: "Zoom In"),
        Slot(identifier: "com.apple.cursor.43", displayName: "Zoom Out"),
    ]

    public static let byIdentifier: [String: Slot] =
        Dictionary(uniqueKeysWithValues: all.map { ($0.identifier, $0) })

    public static func isValid(_ identifier: String) -> Bool {
        byIdentifier[identifier] != nil
    }

    public static func displayName(for identifier: String) -> String {
        byIdentifier[identifier]?.displayName ?? identifier
    }
}

extension Slot: Identifiable {
    public var id: String { identifier }
}

extension Slots {
    public static let indexByIdentifier: [String: Int] = Dictionary(
        uniqueKeysWithValues: all.enumerated().map { ($0.element.identifier, $0.offset) })
}

extension Slots {
    public static let intentionallyExcludedFromCursorMap: Set<String> = [
        "com.apple.coregraphics.ArrowS",
        "com.apple.coregraphics.IBeamS",
    ]
}

extension Slots {
    public static let redundantAliases: Set<String> = [
        "com.apple.cursor.0",
        "com.apple.cursor.1",
    ]

    public static let standard: [Slot] =
        all.filter { !redundantAliases.contains($0.identifier) }

    public static func gridSlots(rowIdentifiers: Set<String>,
                                 selectedIdentifier: String?) -> [Slot] {
        all.filter {
            !redundantAliases.contains($0.identifier)
                || rowIdentifiers.contains($0.identifier)
                || selectedIdentifier == $0.identifier
        }
    }
}
