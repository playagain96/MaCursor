import Foundation

extension Notification.Name {
    static let cursorLibraryWillSave = Notification.Name("MACLibraryWillSave")
    static let cursorLibraryDidSave  = Notification.Name("MACLibraryDidSave")
    static let cursorLibraryIdentifierDidChange = Notification.Name("MACLibraryIdentifierDidChange")
    static let hideTahoeCursorsChanged = Notification.Name("MACHideTahoeCursorsChanged")
}

class CursorLibrary: NSObject, NSCopying, @unchecked Sendable {


    var name: String {
        didSet {
            guard name != oldValue else { return }
            let previous = oldValue
            undoManager.registerUndo(withTarget: self) { target in
                target.name = previous
            }
            if !undoManager.isUndoing {
                undoManager.setActionName(NSLocalizedString("Change Name", comment: "Undo change cursor theme name"))
            }
        }
    }

    var creator: String {
        didSet {
            guard creator != oldValue else { return }
            let previous = oldValue
            undoManager.registerUndo(withTarget: self) { target in
                target.creator = previous
            }
            if !undoManager.isUndoing {
                undoManager.setActionName(NSLocalizedString("Change Creator", comment: "Undo change cursor theme creator"))
            }
        }
    }

    var identifier: String {
        didSet {
            guard identifier != oldValue else { return }
            oldIdentifier = oldValue
            let previous = oldValue
            undoManager.registerUndo(withTarget: self) { target in
                target.identifier = previous
            }
            if !undoManager.isUndoing {
                undoManager.setActionName(NSLocalizedString("Change Identifier", comment: "Undo change cursor theme identifier"))
            }
        }
    }

    var version: NSNumber {
        didSet {
            guard version != oldValue else { return }
            let previous = oldValue
            undoManager.registerUndo(withTarget: self) { target in
                target.version = previous
            }
            if !undoManager.isUndoing {
                undoManager.setActionName(NSLocalizedString("Change Version", comment: "Undo change cursor theme version"))
            }
        }
    }

    private(set) var uuid: String

    var fileURL: URL?

    weak var library: LibraryController?

    var isHiDPI: Bool {
        didSet {
            guard isHiDPI != oldValue else { return }
            let previous = oldValue
            undoManager.registerUndo(withTarget: self) { target in
                target.isHiDPI = previous
            }
            if !undoManager.isUndoing {
                undoManager.setActionName(NSLocalizedString("Change HiDPI", comment: "Undo change cursor theme hidpi"))
            }
        }
    }


    private(set) var cursors: Set<MACCursorSwift> = []


    let undoManager: UndoManager


    private var changeCount: Int = 0
    private var lastChangeCount: Int = 0

    var isDirty: Bool {
        changeCount != lastChangeCount
    }

    private(set) var oldIdentifier: String?


    private var undoObservers: [Any] = []


    private static let cursorUndoProperties: [String: String] = [
        "identifier":    NSLocalizedString("cursor type", comment: "Undo change cursor type suffix"),
        "frameDuration": NSLocalizedString("frame duration", comment: "Undo change cursor frame duration suffix"),
        "frameCount":    NSLocalizedString("frame count", comment: "Undo change cursor frame count suffix"),
        "size":          NSLocalizedString("dimensions", comment: "Undo change cursor image dimensions suffix"),
        "hotSpot":       NSLocalizedString("hotspot", comment: "Undo change cursor hotspot suffix"),
    ]


    static func sanitizeName(_ name: String) -> String {
        let sanitized = name
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "/", with: "")
            .replacingOccurrences(of: ":", with: "")
        return sanitized.isEmpty ? "Unnamed" : sanitized
    }

    static func generateIdentifier(from name: String) -> String {
        return sanitizeName(name)
    }

    static func updateIdentifier(_ existingId: String, newName: String) -> String {
        return sanitizeName(newName)
    }


    override init() {
        let um = UndoManager()
        self.undoManager = um
        self.name = NSLocalizedString("Unnamed", comment: "Default New Cursor Theme Name")
        self.creator = NSUserName()
        self.isHiDPI = false
        self.identifier = CursorLibrary.generateIdentifier(from: "Unnamed")
        self.version = NSNumber(value: 1.0)
        self.uuid = UUID().uuidString

        super.init()

        setupUndoObservers()
    }


    convenience init?(contentsOfFile path: String) {
        self.init(contentsOfURL: URL(fileURLWithPath: path))
    }

    convenience init?(contentsOfURL url: URL) {
        guard let dict = NSDictionary(contentsOf: url) as? [String: Any] else { return nil }
        self.init(dictionary: dict)
        self.fileURL = url
    }

    convenience init?(dictionary: [String: Any]) {
        self.init()
        if !readFromDictionary(dictionary) {
            return nil
        }
    }

    convenience init(cursors: Set<MACCursorSwift>) {
        self.init()
        self.cursors = cursors
    }

    deinit {
        for observer in undoObservers {
            NotificationCenter.default.removeObserver(observer)
        }
    }


    private func setupUndoObservers() {
        let center = NotificationCenter.default

        let ob1 = center.addObserver(forName: .NSUndoManagerDidCloseUndoGroup, object: undoManager, queue: nil) { [weak self] _ in
            self?.updateChangeCount(.changeDone)
        }
        let ob2 = center.addObserver(forName: .NSUndoManagerDidUndoChange, object: undoManager, queue: nil) { [weak self] _ in
            self?.updateChangeCount(.changeUndone)
        }
        let ob3 = center.addObserver(forName: .NSUndoManagerDidRedoChange, object: undoManager, queue: nil) { [weak self] _ in
            self?.updateChangeCount(.changeRedone)
        }

        undoObservers = [ob1, ob2, ob3]
    }


    private func readFromDictionary(_ dictionary: [String: Any]) -> Bool {
        guard !dictionary.isEmpty else {
            NSLog("cannot make library from empty dictionary")
            return false
        }

        cursors = []
        undoManager.disableUndoRegistration()
        defer { undoManager.enableUndoRegistration() }

        let cursorDicts    = dictionary[MACConstants.cursorsKey] as? [String: Any]
        let creatorStr     = dictionary[MACConstants.creatorKey] as? String
        let hiDPINum       = dictionary[MACConstants.hiDPIKey] as? NSNumber
        let identifierStr  = dictionary[MACConstants.identifierKey] as? String
        let themeName      = dictionary[MACConstants.themeNameKey] as? String
        let themeVersion   = dictionary[MACConstants.themeVersionKey] as? NSNumber
        let uuidStr        = dictionary[MACConstants.uuidKey] as? String

        self.name       = themeName ?? ""
        self.version    = themeVersion ?? NSNumber(value: 1.0)
        self.creator    = creatorStr ?? ""
        self.identifier = identifierStr ?? ""
        self.isHiDPI    = hiDPINum?.boolValue ?? false

        guard !self.identifier.isEmpty else {
            NSLog("cannot make library from dictionary with no identifier")
            return false
        }

        guard let uuidStr, !uuidStr.isEmpty else {
            NSLog("cannot make library from dictionary with no UUID")
            return false
        }

        self.uuid = uuidStr

        if let cursorDicts {
            addCursors(from: cursorDicts)
        }

        return true
    }

    private func addCursors(from cursorDicts: [String: Any]) {
        for (key, value) in cursorDicts {
            guard let cursorDict = value as? [AnyHashable: Any] else { continue }
            guard let cursor = MACCursorSwift(cursorDictionary: cursorDict) else { continue }
            cursor.identifier = key
            addCursor(cursor)
        }
    }

    func dictionaryRepresentation() -> [String: Any] {
        var drep = [String: Any]()

        drep[MACConstants.themeNameKey]      = name
        drep[MACConstants.themeVersionKey]   = version
        drep[MACConstants.creatorKey]        = creator
        drep[MACConstants.hiDPIKey]          = NSNumber(value: isHiDPI)
        drep[MACConstants.identifierKey]     = identifier
        drep[MACConstants.uuidKey]           = uuid

        var cursorsDict = [String: Any]()
        for cursor in cursors {
            if let id = cursor.identifier {
                cursorsDict[id] = cursor.dictionaryRepresentation() as Any
            }
        }

        drep[MACConstants.cursorsKey] = cursorsDict

        return drep
    }


    func cursors(withIdentifier identifier: String) -> Set<MACCursorSwift> {
        Set(cursors.filter { $0.identifier == identifier })
    }

    func addCursor(_ cursor: MACCursorSwift) {
        guard !cursors.contains(cursor) else { return }

        undoManager.registerUndo(withTarget: self) { target in
            target.removeCursor(cursor)
        }
        if !undoManager.isUndoing {
            undoManager.setActionName(NSLocalizedString("Add Cursor", comment: "Add Cursor Undo Title"))
        }

        cursors.insert(cursor)
    }

    func removeCursor(_ cursor: MACCursorSwift) {
        undoManager.registerUndo(withTarget: self) { target in
            target.addCursor(cursor)
        }
        if !undoManager.isUndoing {
            undoManager.setActionName(NSLocalizedString("Remove Cursor", comment: "Remove Cursor Undo Title"))
        }

        cursors.remove(cursor)
    }

    func removeCursors(withIdentifier identifier: String) {
        for cursor in cursors(withIdentifier: identifier) {
            removeCursor(cursor)
        }
    }


    @discardableResult
    func write(toFile path: String, atomically: Bool) -> Bool {
        let dict = dictionaryRepresentation() as NSDictionary
        return dict.write(toFile: path, atomically: atomically)
    }

    func save() -> Error? {
        let identifiers = cursors.compactMap { $0.identifier }.filter { !$0.isEmpty }
        let counted = NSCountedSet(array: identifiers)
        var duplicates = Set<String>()

        for case let identifier as String in counted {
            if counted.count(for: identifier) > 1 {
                duplicates.insert(MACConstants.nameForIdentifier(identifier))
            }
        }

        if !duplicates.isEmpty {
            return NSError(
                domain: MACConstants.errorDomain,
                code: MACConstants.ErrorCode.multipleCursorIdentifiers.rawValue,
                userInfo: [
                    NSLocalizedDescriptionKey: NSLocalizedString("Save failed", comment: "New Cursor Theme Failure Title"),
                    NSLocalizedFailureReasonErrorKey: String(format: NSLocalizedString("Multiple cursors with the name(s): %@ exist.", comment: "New Cursor Theme Failure Duplicate cursor name error"), duplicates)
                ]
            )
        }

        NotificationCenter.default.post(name: .cursorLibraryWillSave, object: self)

        guard let path = fileURL?.path else {
            return NSError(
                domain: MACConstants.errorDomain,
                code: MACConstants.ErrorCode.writeFail.rawValue,
                userInfo: [
                    NSLocalizedDescriptionKey: NSLocalizedString("Save failed", comment: "New Cursor Theme Failure Title"),
                    NSLocalizedFailureReasonErrorKey: NSLocalizedString("No file URL set.", comment: "No file URL error")
                ]
            )
        }

        if write(toFile: path, atomically: true) {
            updateChangeCount(.changeCleared)
            NotificationCenter.default.post(name: .cursorLibraryDidSave, object: self)
            return nil
        }

        return NSError(
            domain: MACConstants.errorDomain,
            code: MACConstants.ErrorCode.writeFail.rawValue,
            userInfo: [
                NSLocalizedDescriptionKey: NSLocalizedString("Save failed", comment: "New Cursor Theme Failure Title"),
                NSLocalizedFailureReasonErrorKey: NSLocalizedString("Error writing cursor theme to disk.", comment: "New Cursor Theme Failure Filesystem Error")
            ]
        )
    }


    func updateChangeCount(_ change: NSDocument.ChangeType) {
        switch change {
        case .changeDone, .changeRedone:
            changeCount += 1
        case .changeUndone:
            if changeCount > 0 { changeCount -= 1 }
        case .changeCleared, .changeAutosaved:
            lastChangeCount = changeCount
        @unknown default:
            break
        }
    }

    func revertToSaved() {
        while isDirty {
            undoManager.undo()
        }
        updateChangeCount(.changeCleared)
        undoManager.removeAllActions()
    }


    func copy(with zone: NSZone? = nil) -> Any {
        let copy = CursorLibrary(cursors: cursors)
        copy.undoManager.disableUndoRegistration()
        copy.name = name
        copy.creator = creator
        copy.isHiDPI = isHiDPI
        copy.version = version
        copy.identifier = CursorLibrary.generateIdentifier(from: name)
        copy.uuid = UUID().uuidString
        copy.undoManager.enableUndoRegistration()
        return copy
    }


    override func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? CursorLibrary else { return false }
        return name == other.name
            && creator == other.creator
            && identifier == other.identifier
            && version == other.version
            && isHiDPI == other.isHiDPI
            && cursors == other.cursors
    }

    override var hash: Int {
        var hasher = Hasher()
        hasher.combine(identifier)
        return hasher.finalize()
    }
}
