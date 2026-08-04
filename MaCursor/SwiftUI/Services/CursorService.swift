import Foundation

enum CursorService {
    static func applyTheme(atPath path: String) -> Bool {
        guard themeFileHasApplicableCursor(atPath: path) else {
            NSLog("MaCursor: refusing to apply %@ — no cursor in it has both an image and a known cursor type", path)
            return false
        }
        return applyThemeAtPath(path)
    }

    static func themeFileHasApplicableCursor(atPath path: String) -> Bool {
        guard let theme = NSDictionary(contentsOf: URL(fileURLWithPath: path)) as? [String: Any],
              let cursors = theme[MACConstants.cursorsKey] as? [String: Any] else { return false }

        return cursors.contains { identifier, entry in
            guard MACConstants.isKnownIdentifier(identifier),
                  let cursor = entry as? [String: Any],
                  let representations = cursor[MACConstants.representationsKey] as? [Any] else { return false }
            return !representations.isEmpty
        }
    }

    static func applyTheme(from library: CursorLibrary) -> Bool {
        guard let path = library.fileURL?.path else {
            return false
        }
        return applyTheme(atPath: path)
    }

    @discardableResult
    static func restoreAll() -> Bool {
        return resetAllCursors(nil)
    }

    static func currentScale() -> Float {
        return cursorScale()
    }

    static func defaultScale() -> Float {
        return defaultCursorScale()
    }

    @discardableResult
    static func setScale(_ scale: Float) -> Bool {
        return setCursorScale(scale)
    }

    @discardableResult
    static func assertPreferredScale() -> Bool {
        return assertPreferredCursorScale()
    }
}
