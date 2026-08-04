import Foundation

enum MACCursorScaleValue: Int, CaseIterable {
    case none = 0
    case x1   = 100
    case x2   = 200
    case x5   = 500
    case x10  = 1000

    static func from(scale: CGFloat) -> MACCursorScaleValue {
        guard scale >= 0 else { return .none }
        return MACCursorScaleValue(rawValue: Int(scale * 100)) ?? .none
    }
}

enum MACConstants {


    static let errorDomain = "com.writronic.macursor.error"


    static let websiteURL = URL(string: "https://writronic.com")!
    static let donateURL  = URL(string: "https://writronic.com/donate")!


    enum ErrorCode: Int {
        case invalidTheme             = -1
        case writeFail                = -2
        case invalidFormat            = -100
        case multipleCursorIdentifiers = -101
        case slotOrderConflict        = -102
    }



    static let cursorsKey        = "Cursors"
    static let creatorKey        = "Creator"
    static let hiDPIKey          = "HiDPI"
    static let identifierKey     = "Identifier"
    static let themeNameKey      = "ThemeName"
    static let themeVersionKey   = "ThemeVersion"
    static let uuidKey           = "UUID"


    static let frameCountKey       = "FrameCount"
    static let frameDurationKey    = "FrameDuration"
    static let hotSpotXKey         = "HotSpotX"
    static let hotSpotYKey         = "HotSpotY"
    static let pointsWideKey       = "PointsWide"
    static let pointsHighKey       = "PointsHigh"
    static let representationsKey  = "Representations"


    static let hiddenCursorAliases: Set<String> = [
        "com.apple.coregraphics.ArrowS",
        "com.apple.coregraphics.IBeamS",
    ]

    static let redundantCursorAliases: Set<String> = [
        "com.apple.cursor.0",
        "com.apple.cursor.1",
    ]

    static let cursorMap: [String: String] = [
        "com.apple.coregraphics.Arrow":    "Arrow",
        "com.apple.coregraphics.IBeam":    "IBeam",
        "com.apple.coregraphics.IBeamXOR": "IBeamXOR",
        "com.apple.coregraphics.Alias":    "Alias",
        "com.apple.coregraphics.Copy":     "Copy",
        "com.apple.coregraphics.Move":     "Move",
        "com.apple.coregraphics.ArrowCtx": "Ctx Arrow",
        "com.apple.coregraphics.Wait":     "Wait",
        "com.apple.coregraphics.Empty":    "Empty",
        "com.apple.cursor.0":  "Arrow",
        "com.apple.cursor.1":  "IBeam",
        "com.apple.cursor.2":  "Link",
        "com.apple.cursor.3":  "Forbidden",
        "com.apple.cursor.4":  "Busy",
        "com.apple.cursor.5":  "Copy Drag",
        "com.apple.cursor.7":  "Crosshair",
        "com.apple.cursor.8":  "Crosshair 2",
        "com.apple.cursor.9":  "Camera 2",
        "com.apple.cursor.10": "Camera",
        "com.apple.cursor.11": "Closed",
        "com.apple.cursor.12": "Open",
        "com.apple.cursor.13": "Pointing",
        "com.apple.cursor.14": "Counting Up",
        "com.apple.cursor.15": "Counting Down",
        "com.apple.cursor.16": "Counting Up/Down",
        "com.apple.cursor.17": "Resize W",
        "com.apple.cursor.18": "Resize E",
        "com.apple.cursor.19": "Resize W-E",
        "com.apple.cursor.20": "Cell XOR",
        "com.apple.cursor.21": "Resize N",
        "com.apple.cursor.22": "Resize S",
        "com.apple.cursor.23": "Resize N-S",
        "com.apple.cursor.24": "Ctx Menu",
        "com.apple.cursor.25": "Poof",
        "com.apple.cursor.26": "IBeam H.",
        "com.apple.cursor.27": "Window E",
        "com.apple.cursor.28": "Window E-W",
        "com.apple.cursor.29": "Window NE",
        "com.apple.cursor.30": "Window NE-SW",
        "com.apple.cursor.31": "Window N",
        "com.apple.cursor.32": "Window N-S",
        "com.apple.cursor.33": "Window NW",
        "com.apple.cursor.34": "Window NW-SE",
        "com.apple.cursor.35": "Window SE",
        "com.apple.cursor.36": "Window S",
        "com.apple.cursor.37": "Window SW",
        "com.apple.cursor.38": "Window W",
        "com.apple.cursor.39": "Resize Square",
        "com.apple.cursor.40": "Help",
        "com.apple.cursor.41": "Cell",
        "com.apple.cursor.42": "Zoom In",
        "com.apple.cursor.43": "Zoom Out",
        "com.apple.coregraphics.ArrowS": "Arrow (Tahoe)",
        "com.apple.coregraphics.IBeamS": "IBeam (Tahoe)",
    ]

    static func tahoeAliases(for identifier: String) -> [String] {
        let map: [String: [String]] = [
            "com.apple.coregraphics.Arrow":  ["com.apple.coregraphics.ArrowS"],
            "com.apple.coregraphics.IBeam":  ["com.apple.coregraphics.IBeamS"],
            "com.apple.coregraphics.ArrowS": ["com.apple.coregraphics.Arrow"],
            "com.apple.coregraphics.IBeamS": ["com.apple.coregraphics.IBeam"],
        ]
        return map[identifier] ?? []
    }

    private static let reverseMap: [String: String] = {
        var map = [String: String]()
        for (key, value) in cursorMap {
            map[value] = key
        }
        return map
    }()


    static func nameForIdentifier(_ identifier: String) -> String {
        return cursorMap[identifier] ?? "Unknown"
    }

    static func isKnownIdentifier(_ identifier: String) -> Bool {
        return cursorMap[identifier] != nil
    }

    static func identifierForName(_ name: String) -> String? {
        return reverseMap[name]
    }
}
