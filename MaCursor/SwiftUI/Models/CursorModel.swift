import Foundation
import AppKit
import Observation

@Observable
class CursorModel: Identifiable, Hashable {
    let id: String
    var identifier: String

    var name: String {
        let resolved = CursorIdentifier.displayName(for: identifier)
        if resolved == identifier || resolved.isEmpty {
            if identifier.contains(".") {
                return String(identifier.split(separator: ".").last ?? Substring(identifier))
            }
            return identifier.isEmpty ? "Unknown" : identifier
        }
        return resolved
    }

    var frameCount: Int
    var frameDuration: Double
    var hotSpot: CGPoint
    var size: CGSize

    var representationRevision: Int = 0

    let backingCursor: MACCursorSwift


    @ObservationIgnored private var _primaryImageCache: NSImage?
    @ObservationIgnored private var _primaryImageCacheRevision: Int = -1

    @ObservationIgnored private var _scaleImageCache: [Int: NSImage] = [:]
    @ObservationIgnored private var _scaleImageCacheRevision: Int = -1

    @ObservationIgnored private var _frameCache: [String: NSImage] = [:]
    @ObservationIgnored private var _frameCacheRevision: Int = -1

    init(from cursor: MACCursorSwift, parentIdentifier: String? = nil) {
        self.backingCursor = cursor
        let rawId = (cursor.identifier?.isEmpty == false) ? cursor.identifier! : UUID().uuidString
        if let parentId = parentIdentifier, !parentId.isEmpty {
            self.id = "\(parentId)/\(rawId)"
        } else {
            self.id = rawId
        }
        self.identifier = cursor.identifier ?? ""

        self.frameCount = Int(cursor.frameCount)
        self.frameDuration = cursor.frameDuration
        self.hotSpot = CGPoint(x: cursor.hotSpot.x, y: cursor.hotSpot.y)
        self.size = CGSize(width: cursor.size.width, height: cursor.size.height)
    }

    func syncToBacking() {
        backingCursor.identifier = identifier
        backingCursor.frameCount = UInt(frameCount)
        backingCursor.frameDuration = frameDuration
        backingCursor.hotSpot = NSPoint(x: hotSpot.x, y: hotSpot.y)
        backingCursor.size = NSSize(width: size.width, height: size.height)
    }

    func image(forScale scale: Int) -> NSImage? {
        _ = representationRevision

        if _scaleImageCacheRevision == representationRevision, let cached = _scaleImageCache[scale] {
            return cached
        }

        if _scaleImageCacheRevision != representationRevision {
            _scaleImageCache.removeAll()
            _scaleImageCacheRevision = representationRevision
        }

        guard let scaleEnum = MACCursorScale(rawValue: UInt(scale)),
              let rep = backingCursor.representation(for: scaleEnum) else {
            return nil
        }
        let image = NSImage(size: NSSize(
            width: size.width,
            height: size.height * CGFloat(max(1, frameCount))
        ))
        image.addRepresentation(rep)
        _scaleImageCache[scale] = image
        return image
    }

    var primaryImage: NSImage? {
        _ = representationRevision

        if _primaryImageCacheRevision == representationRevision {
            return _primaryImageCache
        }

        let staticImage = image(forScale: 200) ?? image(forScale: 100) ?? backingCursor.imageWithAllReps()
        let img = frameCount > 1 ? (previewFrame(at: 0) ?? staticImage) : staticImage
        _primaryImageCache = img
        _primaryImageCacheRevision = representationRevision
        return img
    }

    func thumbnailImage(forScale scale: Int) -> NSImage? {
        if frameCount > 1, let firstFrame = frame(at: 0, scale: scale) {
            return firstFrame
        }
        return image(forScale: scale)
    }

    var cursorTypeName: String {
        guard !identifier.isEmpty else {
            return String(localized: "Unassigned",
                          comment: "Cursor list label: the slot has no cursor type assigned")
        }
        let parts = identifier.split(separator: ".")
        if parts.count >= 2 {
            return parts.suffix(2).joined(separator: ".")
        }
        return identifier
    }

    func frame(at index: Int, scale: Int = 100) -> NSImage? {
        _ = representationRevision

        let cacheKey = "\(scale)_\(index)_\(frameCount)_\(size.width)x\(size.height)"
        if _frameCacheRevision == representationRevision, let cached = _frameCache[cacheKey] {
            return cached
        }

        if _frameCacheRevision != representationRevision {
            _frameCache.removeAll()
            _frameCacheRevision = representationRevision
        }

        guard let scaleEnum = MACCursorScale(rawValue: UInt(scale)),
              let rep = backingCursor.representation(for: scaleEnum) else {
            return nil
        }

        guard frameCount > 0, index < frameCount, size.height > 0 else { return nil }

        let pixelFrameHeight = rep.pixelsHigh / frameCount
        guard pixelFrameHeight > 0 else { return nil }
        let yOffset = index * pixelFrameHeight

        let fullImage = NSImage(size: NSSize(width: rep.pixelsWide, height: rep.pixelsHigh))
        fullImage.addRepresentation(rep)

        var proposedRect = CGRect(origin: .zero, size: CGSize(width: rep.pixelsWide, height: rep.pixelsHigh))
        guard let fullCGImage = fullImage.cgImage(forProposedRect: &proposedRect, context: nil, hints: nil) else { return nil }
        let cropRect = CGRect(x: 0, y: yOffset, width: fullCGImage.width, height: pixelFrameHeight)
        guard let croppedCGImage = fullCGImage.cropping(to: cropRect) else { return nil }

        let frameImage = NSImage(size: NSSize(width: size.width, height: size.height))
        let frameRep = NSBitmapImageRep(cgImage: croppedCGImage)
        frameRep.size = NSSize(width: size.width, height: size.height)
        frameImage.addRepresentation(frameRep)

        _frameCache[cacheKey] = frameImage
        return frameImage
    }

    func previewFrame(at index: Int) -> NSImage? {
        frame(at: index, scale: 200) ?? frame(at: index, scale: 100)
            ?? frame(at: index, scale: 500) ?? frame(at: index, scale: 1000)
    }

    var hasRepresentations: Bool {
        _ = representationRevision
        return ((backingCursor.representations as? [String: Any])?.isEmpty == false)
    }


    func setRepresentation(_ rep: NSBitmapImageRep, forScale scale: Int) {
        guard let scaleEnum = MACCursorScale(rawValue: UInt(scale)) else { return }

        backingCursor.frameCount = UInt(frameCount)

        if size.width <= 0 || size.height <= 0 {
            size = CursorGeometry.baseSize(matchingAspectOf: rep, frameCount: frameCount)
        }

        let normalized = SlotImageImporter.normalized(
            rep,
            forScaleValue: UInt(scale),
            pointWidth: CursorGeometry.normalizedPointWidth(size.width),
            frameCount: max(1, frameCount)
        )

        backingCursor.setRepresentation(normalized, for: scaleEnum)
        representationRevision += 1

        backingCursor.size = NSSize(width: size.width, height: size.height)
    }

    func removeRepresentation(forScale scale: Int) {
        guard let scaleEnum = MACCursorScale(rawValue: UInt(scale)) else { return }
        backingCursor.removeRepresentation(for: scaleEnum)
        representationRevision += 1
    }

    struct SlotOrderConflict: Equatable {
        let targetScale: Int
        let conflictingScale: Int
    }

    func slotOrderConflict(pixelsWide: Int, pixelsHigh: Int, frameCount incomingFrameCount: Int?, targetScale: Int) -> SlotOrderConflict? {
        guard pixelsWide > 0, pixelsHigh > 0 else { return nil }
        let effectiveFrames = max(1, incomingFrameCount ?? frameCount)
        let incomingWidth = pixelsWide
        let incomingHeight = pixelsHigh / effectiveFrames
        guard incomingHeight > 0 else { return nil }

        let reps = (backingCursor.representations as? [String: NSBitmapImageRep]) ?? [:]
        let occupied = reps.compactMap { key, rep -> (scale: Int, width: Int, height: Int)? in
            guard let scale = Int(key), scale > 0,
                  CursorGeometry.ladder.contains(UInt(scale)),
                  scale != targetScale else { return nil }
            let width = rep.pixelsWide
            let height = rep.pixelsHigh / effectiveFrames
            guard width > 0, height > 0 else { return nil }
            return (scale, width, height)
        }.sorted { $0.scale < $1.scale }

        for slot in occupied {
            if slot.scale < targetScale {
                if incomingWidth <= slot.width || incomingHeight <= slot.height {
                    return SlotOrderConflict(targetScale: targetScale, conflictingScale: slot.scale)
                }
            } else if incomingWidth >= slot.width || incomingHeight >= slot.height {
                return SlotOrderConflict(targetScale: targetScale, conflictingScale: slot.scale)
            }
        }
        return nil
    }

    func applyOrderedRepresentation(_ rep: NSBitmapImageRep,
                                    forScale scale: Int,
                                    frameCount incomingFrameCount: Int? = nil,
                                    frameDuration incomingFrameDuration: Double = 0) -> SlotOrderConflict? {
        if let conflict = slotOrderConflict(pixelsWide: rep.pixelsWide,
                                            pixelsHigh: rep.pixelsHigh,
                                            frameCount: incomingFrameCount,
                                            targetScale: scale) {
            return conflict
        }
        if let installedFrameCount = incomingFrameCount {
            frameCount = installedFrameCount
            frameDuration = incomingFrameDuration
        }
        setRepresentation(rep, forScale: scale)
        return nil
    }

    func canAcceptAnimatedRepresentation(frameCount newFrameCount: Int, pixelsWide: Int, pixelsHigh: Int, replacingScale scale: Int) -> Bool {
        guard newFrameCount > 0,
              pixelsWide > 0,
              pixelsHigh > 0,
              pixelsHigh.isMultiple(of: newFrameCount) else { return false }

        let reps = (backingCursor.representations as? [String: Any]) ?? [:]
        let hasOtherScales = reps.keys.contains { $0 != "\(scale)" }
        if hasOtherScales, frameCount != newFrameCount { return false }

        guard size.width.isFinite,
              size.height.isFinite,
              size.width > 0,
              size.height > 0 else { return !hasOtherScales }

        let frameHeight = CGFloat(pixelsHigh / newFrameCount)
        let artworkAspect = CGFloat(pixelsWide) / frameHeight
        let pointAspect = size.width / size.height
        let relativeDifference = abs(artworkAspect - pointAspect) / pointAspect
        return relativeDifference <= 0.05
    }


    static func == (lhs: CursorModel, rhs: CursorModel) -> Bool {
        lhs === rhs
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
