import Foundation

public enum ModelError: Error, Equatable, Sendable {
    case invalidHotspot(x: Double, y: Double, width: Int, height: Int)
    case emptyCursor
}

public enum CursorReadError: Error, Sendable {
    case notThisFormat(String)
    case truncated(context: String)
    case malformed(String)
    case unsupportedImage(String)
}

public enum ThemeImportError: Error, Sendable, Equatable {
    case nothingMappable
    case unreadableInput(String)
    case unsupportedInput(String)
    case multipleThemes(count: Int)
}

public enum ThemeBuildError: Error, Sendable {
    case emptyTheme
    case invalidThemeName(String)
    case compositionFailed(String)
    case selfCheckFailed([String])
}

extension ModelError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .invalidHotspot(let x, let y, let width, let height):
            return String(localized: "Hotspot \(Int(x)),\(Int(y)) is outside the \(width)×\(height) image.",
                          comment: "Conversion error: the hot spot lies outside the cursor image")
        case .emptyCursor:
            return String(localized: "The cursor has no images.",
                          comment: "Conversion error: the cursor carries no image data")
        }
    }
}

extension CursorReadError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .notThisFormat(let format):
            return "Not a \(format) file."
        case .truncated(let context):
            return "File ends unexpectedly while reading \(context)."
        case .malformed(let detail):
            return "Corrupt cursor data: \(detail)."
        case .unsupportedImage(let detail):
            return "Embedded image could not be decoded: \(detail)."
        }
    }
}

extension ThemeImportError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .nothingMappable:
            return String(localized: "No cursors in the input could be mapped to macOS cursor slots.",
                          comment: "Conversion error: nothing in the source maps to a macOS cursor slot")
        case .unreadableInput(let path):
            return String(localized: "Cannot read input: \(path).",
                          comment: "Conversion error: the chosen file or folder could not be read")
        case .unsupportedInput(let detail):
            return String(localized: "\(detail) Convert Theme accepts a Mousecape .cape file, a Windows cursor folder, or a Linux Xcursor theme folder.",
                          comment: "Conversion error: unsupported input; %@ is a sentence naming the specific reason")
        case .multipleThemes(let count):
            return String(localized: "This folder holds \(count) theme files. Choose a single one to convert.",
                          comment: "Conversion error: the chosen folder holds more than one theme")
        }
    }
}

extension ThemeBuildError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .emptyTheme:
            return String(localized: "The theme has no cursors to write.",
                          comment: "Conversion error: the converted theme ended up with no cursors")
        case .invalidThemeName(let name):
            return String(localized: "Theme name “\(name)” contains no usable characters.",
                          comment: "Conversion error: the theme name yields no valid identifier")
        case .compositionFailed(let detail):
            return "Sprite-sheet composition failed: \(detail)."
        case .selfCheckFailed(let problems):
            return "The written theme failed validation: \(problems.joined(separator: "; "))."
        }
    }
}
