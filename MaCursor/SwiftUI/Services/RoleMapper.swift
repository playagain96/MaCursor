import Foundation

public struct RoleMapping: Sendable, Equatable {
    public let primary: String
    public let secondaries: [String]

    public init(primary: String, secondaries: [String] = []) {
        self.primary = primary
        self.secondaries = secondaries
    }
}

public enum MappingTier: Int, Sendable, Comparable {
    case infDeclaration = 0
    case exactName = 1
    case heuristic = 2

    public static func < (lhs: MappingTier, rhs: MappingTier) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

public enum RoleMapper {

    public static func normalize(_ raw: String) -> String {
        let stem = (raw as NSString).deletingPathExtension
        return stem.lowercased()
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .joined(separator: " ")
    }

    public static let x11NameToIdentifier: [String: RoleMapping] = [
        "default": RoleMapping(primary: "com.apple.coregraphics.Arrow",
                               secondaries: ["com.apple.coregraphics.ArrowCtx"]),
        "text": RoleMapping(primary: "com.apple.coregraphics.IBeam",
                            secondaries: ["com.apple.coregraphics.IBeamXOR"]),
        "wait": RoleMapping(primary: "com.apple.coregraphics.Wait"),
        "alias": RoleMapping(primary: "com.apple.coregraphics.Alias",
                             secondaries: ["com.apple.cursor.2"]),
        "copy": RoleMapping(primary: "com.apple.coregraphics.Copy",
                            secondaries: ["com.apple.cursor.5"]),
        "no-drop": RoleMapping(primary: "com.apple.cursor.3"),
        "not-allowed": RoleMapping(primary: "com.apple.cursor.3"),
        "dnd-no-drop": RoleMapping(primary: "com.apple.cursor.3"),
        "progress": RoleMapping(primary: "com.apple.cursor.4"),
        "crosshair": RoleMapping(primary: "com.apple.cursor.7",
                                 secondaries: ["com.apple.cursor.8"]),
        "dnd-move": RoleMapping(primary: "com.apple.cursor.11"),
        "openhand": RoleMapping(primary: "com.apple.cursor.12"),
        "pointer": RoleMapping(primary: "com.apple.cursor.13"),
        "left_side": RoleMapping(primary: "com.apple.cursor.17"),
        "right_side": RoleMapping(primary: "com.apple.cursor.18"),
        "col-resize": RoleMapping(primary: "com.apple.cursor.19"),
        "top_side": RoleMapping(primary: "com.apple.cursor.21"),
        "bottom_side": RoleMapping(primary: "com.apple.cursor.22"),
        "row-resize": RoleMapping(primary: "com.apple.cursor.23"),
        "context-menu": RoleMapping(primary: "com.apple.cursor.24"),
        "pirate": RoleMapping(primary: "com.apple.cursor.25"),
        "vertical-text": RoleMapping(primary: "com.apple.cursor.26"),
        "right-arrow": RoleMapping(primary: "com.apple.cursor.27"),
        "size_hor": RoleMapping(primary: "com.apple.cursor.28"),
        "size_bdiag": RoleMapping(primary: "com.apple.cursor.30"),
        "up-arrow": RoleMapping(primary: "com.apple.cursor.31"),
        "size_ver": RoleMapping(primary: "com.apple.cursor.32"),
        "size_fdiag": RoleMapping(primary: "com.apple.cursor.34"),
        "down-arrow": RoleMapping(primary: "com.apple.cursor.36"),
        "left-arrow": RoleMapping(primary: "com.apple.cursor.38"),
        "fleur": RoleMapping(primary: "com.apple.coregraphics.Move"),
        "help": RoleMapping(primary: "com.apple.cursor.40"),
        "cell": RoleMapping(primary: "com.apple.cursor.41",
                            secondaries: ["com.apple.cursor.20"]),
        "zoom-in": RoleMapping(primary: "com.apple.cursor.42"),
        "zoom-out": RoleMapping(primary: "com.apple.cursor.43"),
        "all-scroll": RoleMapping(primary: "com.apple.coregraphics.Move"),
        "w-resize": RoleMapping(primary: "com.apple.cursor.17"),
        "e-resize": RoleMapping(primary: "com.apple.cursor.18"),
        "ew-resize": RoleMapping(primary: "com.apple.cursor.19"),
        "n-resize": RoleMapping(primary: "com.apple.cursor.21"),
        "s-resize": RoleMapping(primary: "com.apple.cursor.22"),
        "ns-resize": RoleMapping(primary: "com.apple.cursor.23"),
        "ne-resize": RoleMapping(primary: "com.apple.cursor.29"),
        "nesw-resize": RoleMapping(primary: "com.apple.cursor.30"),
        "nw-resize": RoleMapping(primary: "com.apple.cursor.33"),
        "nwse-resize": RoleMapping(primary: "com.apple.cursor.34"),
        "se-resize": RoleMapping(primary: "com.apple.cursor.35"),
        "sw-resize": RoleMapping(primary: "com.apple.cursor.37"),
        "grab": RoleMapping(primary: "com.apple.cursor.12"),
        "grabbing": RoleMapping(primary: "com.apple.cursor.11"),
        "sizing": RoleMapping(primary: "com.apple.cursor.39"),
    ]

    public static let x11Aliases: [String: String] = [
        "e29285e634086352946a0e7090d73106": "pointer",
        "9d800788f1b08800ae810202380a0822": "pointer",
        "hand1": "pointer",
        "hand2": "pointer",
        "pointing_hand": "pointer",
        "xterm": "text",
        "ibeam": "text",
        "crossed_circle": "not-allowed",
        "circle": "not-allowed",
        "03b6e0fcb3499374a867c041f52298f0": "not-allowed",
        "forbidden": "no-drop",
        "1081e37283d90000800003c07f3ef6bf": "copy",
        "b66166c04f8c3109214a4fbd64a50fc8": "copy",
        "6407b0e94181790501fd1e167b474872": "copy",
        "dnd-copy": "copy",
        "closedhand": "dnd-move",
        "dnd-none": "dnd-move",
        "move": "dnd-move",
        "fcf21c00b30f7e3f83fe0dfd12e71cff": "dnd-move",
        "4498f0e0c1937ffe01fd06f973665830": "dnd-move",
        "9081237383d90e509aa00f00170e968f": "dnd-move",
        "sb_h_double_arrow": "size_hor",
        "h_double_arrow": "size_hor",
        "sb_v_double_arrow": "size_ver",
        "v_double_arrow": "size_ver",
        "00008160000006810000408080010102": "size_ver",
        "split_h": "col-resize",
        "split_v": "row-resize",
        "a2a266d0498c3104214a47bd64ab0fc8": "alias",
        "3085a0e285430894940527032f8b26df": "alias",
        "640fb0e74195791501fd1ed57b41487f": "alias",
        "link": "alias",
        "5c6cd98b3f3ebcb1f9c7f1c204630408": "help",
        "d9ce0ab605698f320427677b458ad60b": "help",
        "question_arrow": "help",
        "whats_this": "help",
        "left_ptr_help": "help",
        "08e8e1c95fe2fc01f976f1e063a24ccd": "progress",
        "3ecb610c1bf2410f44200f48c40d3599": "progress",
        "00000000000000020006000e7e9ffc3f": "progress",
        "left_ptr_watch": "progress",
        "half-busy": "progress",
        "left_ptr": "default",
        "top_left_arrow": "default",
        "watch": "wait",
        "cross": "crosshair",
        "plus": "cell",
        "size_all": "fleur",
        "size-hor": "size_hor",
        "size-ver": "size_ver",
        "size-bdiag": "size_bdiag",
        "size-fdiag": "size_fdiag",
        "top_left_corner": "nw-resize",
        "top_right_corner": "ne-resize",
        "bottom_right_corner": "se-resize",
        "bottom_left_corner": "sw-resize",
        "ul_angle": "nw-resize",
        "ur_angle": "ne-resize",
        "lr_angle": "se-resize",
        "ll_angle": "sw-resize",
        "center_ptr": "up-arrow",
        "sb_up_arrow": "up-arrow",
        "sb_down_arrow": "down-arrow",
        "sb_left_arrow": "left-arrow",
        "sb_right_arrow": "right-arrow",
        "based_arrow_up": "up-arrow",
        "based_arrow_down": "down-arrow",
        "right_ptr": "default",
        "dnd-link": "alias",
        "tcross": "crosshair",
        "clock": "wait",
        "double_arrow": "size_ver",
    ]

    public static let infRoleToIdentifier: [String: RoleMapping] = [
        "pointer": RoleMapping(primary: "com.apple.coregraphics.Arrow",
                               secondaries: ["com.apple.coregraphics.ArrowCtx"]),
        "help": RoleMapping(primary: "com.apple.cursor.40"),
        "work": RoleMapping(primary: "com.apple.cursor.4"),
        "busy": RoleMapping(primary: "com.apple.coregraphics.Wait"),
        "cross": RoleMapping(primary: "com.apple.cursor.7",
                             secondaries: ["com.apple.cursor.8"]),
        "text": RoleMapping(primary: "com.apple.coregraphics.IBeam",
                            secondaries: ["com.apple.coregraphics.IBeamXOR"]),
        "unavailiable": RoleMapping(primary: "com.apple.cursor.3"),
        "unavailable": RoleMapping(primary: "com.apple.cursor.3"),
        "vert": RoleMapping(primary: "com.apple.cursor.23"),
        "horz": RoleMapping(primary: "com.apple.cursor.19"),
        "dgn1": RoleMapping(primary: "com.apple.cursor.34"),
        "dgn2": RoleMapping(primary: "com.apple.cursor.30"),
        "move": RoleMapping(primary: "com.apple.coregraphics.Move"),
        "link": RoleMapping(primary: "com.apple.cursor.13"),
    ]

    public static let deliberatelyUnmappedINFRoles: Set<String> = ["hand", "alternate"]

    public static let windowsFriendlyNameToIdentifier: [String: RoleMapping] = [
        "normal select": RoleMapping(primary: "com.apple.coregraphics.Arrow",
                                     secondaries: ["com.apple.coregraphics.ArrowCtx"]),
        "help select": RoleMapping(primary: "com.apple.cursor.40"),
        "working in background": RoleMapping(primary: "com.apple.cursor.4"),
        "busy": RoleMapping(primary: "com.apple.coregraphics.Wait"),
        "precision select": RoleMapping(primary: "com.apple.cursor.7",
                                        secondaries: ["com.apple.cursor.8"]),
        "text select": RoleMapping(primary: "com.apple.coregraphics.IBeam",
                                   secondaries: ["com.apple.coregraphics.IBeamXOR"]),
        "text select 2": RoleMapping(primary: "com.apple.coregraphics.IBeamXOR"),
        "unavailable": RoleMapping(primary: "com.apple.cursor.3"),
        "vertical resize": RoleMapping(primary: "com.apple.cursor.23"),
        "horizontal resize": RoleMapping(primary: "com.apple.cursor.19"),
        "diagonal resize 1": RoleMapping(primary: "com.apple.cursor.34"),
        "diagonal resize 2": RoleMapping(primary: "com.apple.cursor.30"),
        "move": RoleMapping(primary: "com.apple.coregraphics.Move"),
        "link select": RoleMapping(primary: "com.apple.cursor.13"),
    ]

    public static let deliberatelyUnmappedNames: Set<String> = [
        "handwriting", "alternate select", "location select", "person select",
        "color picker", "draft", "draft large", "draft small", "pencil",
        "spraycan", "dotbox", "draped box",
        "man", "gumby", "gobbler", "trek", "heart", "star", "spider",
        "umbrella", "boat", "sailboat", "shuttle", "rtl logo", "bogosity",
        "exchange", "iron cross", "diamond cross", "box spiral", "dot",
        "target", "icon", "x cursor",
    ]

    public static let heuristicTokens: [(tokens: [String], identifier: String)] = [
        (["arrow", "pointer", "normal", "default"], "com.apple.coregraphics.Arrow"),
        (["beam", "text", "ibeam"], "com.apple.coregraphics.IBeam"),
        (["busy", "wait", "watch"], "com.apple.coregraphics.Wait"),
        (["work", "appstarting", "progress"], "com.apple.cursor.4"),
        (["link", "hand"], "com.apple.cursor.13"),
        (["help", "question"], "com.apple.cursor.40"),
        (["cross", "precision"], "com.apple.cursor.7"),
        (["move", "size_all", "fleur"], "com.apple.coregraphics.Move"),
        (["dgn1", "nwse"], "com.apple.cursor.34"),
        (["dgn2", "nesw"], "com.apple.cursor.30"),
        (["vert", "ns"], "com.apple.cursor.23"),
        (["horz", "ew"], "com.apple.cursor.19"),
        (["unavail", "forbidden", "no"], "com.apple.cursor.3"),
    ]

    public static func mapX11Name(_ name: String) -> RoleMapping? {
        let key = name.lowercased()
        if let mapping = x11NameToIdentifier[key] { return mapping }
        if let canonical = x11Aliases[key] { return x11NameToIdentifier[canonical] }
        return nil
    }

    public static func mapINFRole(_ role: String) -> RoleMapping? {
        infRoleToIdentifier[role.lowercased()]
    }

    public static func mapFilenameHeuristic(_ stem: String) -> RoleMapping? {
        let lower = stem.lowercased()
        for row in heuristicTokens where row.tokens.contains(where: { lower.contains($0) }) {
            return RoleMapping(primary: row.identifier)
        }
        return nil
    }

    public static func mapWindowsFriendlyName(_ raw: String) -> RoleMapping? {
        windowsFriendlyNameToIdentifier[normalize(raw)]
    }

    public static func isDeliberatelyUnmapped(_ rawName: String) -> Bool {
        deliberatelyUnmappedNames.contains(normalize(rawName))
    }
}
