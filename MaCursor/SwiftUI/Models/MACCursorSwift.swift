import AppKit

class MACCursorSwift: MACCursor, @unchecked Sendable {
    
    private var _cachedBitmapReps: [String: NSBitmapImageRep]?
    
    
    override var name: String {
        return MACConstants.nameForIdentifier(identifier ?? "")
    }
    
    
    override func dictionaryRepresentation() -> [AnyHashable : Any]! {
        var drep = [String: Any]()
        drep[MACConstants.frameCountKey] = NSNumber(value: frameCount)
        drep[MACConstants.frameDurationKey] = NSNumber(value: frameDuration)
        drep[MACConstants.hotSpotXKey] = NSNumber(value: hotSpot.x)
        drep[MACConstants.hotSpotYKey] = NSNumber(value: hotSpot.y)
        drep[MACConstants.pointsWideKey] = NSNumber(value: size.width)
        drep[MACConstants.pointsHighKey] = NSNumber(value: size.height)
        
        var pngs = [Data]()
        if let reps = representations as? [String: NSBitmapImageRep] {
            for key in reps.keys.sorted() {
                guard let rep = reps[key] else { continue }
                if let pngData = rep.ensuredSRGBSpace.representation(using: .png, properties: [:]) {
                    pngs.append(pngData)
                }
            }
        }
        drep[MACConstants.representationsKey] = pngs
        
        return drep
    }
    
    
    override func imageWithAllReps() -> NSImage! {
        let image = NSImage(size: NSSize(width: size.width, height: size.height * CGFloat(frameCount)))
        if let reps = representations as? [String: NSImageRep] {
            image.addRepresentations(Array(reps.values))
        }
        return image
    }
    
    
    override func representation(for scale: MACCursorScale) -> NSBitmapImageRep? {
        let reps: [String: NSBitmapImageRep]
        if let cached = _cachedBitmapReps {
            reps = cached
        } else {
            guard let bridged = representations as? [String: NSBitmapImageRep] else { return nil }
            _cachedBitmapReps = bridged
            reps = bridged
        }
        return reps["\(scale.rawValue)"]
    }
    
    override func representation(withScale scale: CGFloat) -> NSImageRep? {
        return representation(for: cursorScaleForScale(scale))
    }
    
    
    override func setRepresentation(_ imageRep: NSImageRep!, for scale: MACCursorScale) {
        let dictKey = "\(scale.rawValue)"
        let kvoKey = "cursorRep\(scale.rawValue)"
        
        _cachedBitmapReps = nil
        
        willChangeValue(forKey: "representations")
        willChangeValue(forKey: kvoKey)
        
        if let bitmapRep = imageRep as? NSBitmapImageRep {
            let existingDict = (representations as? [String: Any]) ?? [:]
            let newMutableDict = NSMutableDictionary(dictionary: existingDict)
            newMutableDict[dictKey] = bitmapRep
            setValue(newMutableDict, forKey: "representations")
            
            if (representations as? NSDictionary)?.count == 1 {
                let s = CGFloat(scale.rawValue) / 100.0
                let newSize = NSSize(
                    width: Double(bitmapRep.pixelsWide) / Double(s),
                    height: Double(bitmapRep.pixelsHigh) / Double(frameCount) / Double(s)
                )
                if newSize != .zero {
                    self.size = newSize
                }
            }
        } else {
            let existingDict = (representations as? [String: Any]) ?? [:]
            let newMutableDict = NSMutableDictionary(dictionary: existingDict)
            newMutableDict.removeObject(forKey: dictKey)
            setValue(newMutableDict, forKey: "representations")
        }
        
        didChangeValue(forKey: kvoKey)
        didChangeValue(forKey: "representations")
    }
    
    override func removeRepresentation(for scale: MACCursorScale) {
        setRepresentation(nil, for: scale)
    }
    
    
    override func addFrame(_ frame: NSImageRep!, for scale: MACCursorScale) {
        guard let existingRep = representation(for: scale) else { return }
        guard let newRep = MACCursorSwift.composeRepresentation(withFrames: [existingRep, frame] as? [NSBitmapImageRep] ?? []) else { return }
        
        let frames = Int(newRep.pixelsHigh) / Int(size.height)
        if frameCount < frames {
            frameCount = UInt(frames)
        }
        
        setRepresentation(newRep, for: scale)
    }
    
    override class func composeRepresentation(withFrames frames: [Any]!) -> NSBitmapImageRep? {
        guard let bitmapFrames = frames as? [NSBitmapImageRep], !bitmapFrames.isEmpty else { return nil }
        if bitmapFrames.count == 1 { return bitmapFrames.first }
        
        let height = bitmapFrames.reduce(0) { $0 + $1.pixelsHigh }
        let width = bitmapFrames[0].pixelsWide
        
        guard let newRep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: width,
            pixelsHigh: height,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 4 * width,
            bitsPerPixel: 32
        ) else { return nil }
        
        guard let ctx = NSGraphicsContext(bitmapImageRep: newRep) else { return nil }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = ctx
        
        var currentY = 0
        for rep in bitmapFrames.reversed() {
            guard rep.pixelsWide == width else {
                NSLog("Can't create representation from images of different widths")
                NSGraphicsContext.restoreGraphicsState()
                return nil
            }
            
            rep.draw(
                in: NSRect(x: 0, y: currentY, width: rep.pixelsWide, height: rep.pixelsHigh),
                from: .zero,
                operation: .sourceOver,
                fraction: 1.0,
                respectFlipped: true,
                hints: nil
            )
            currentY += rep.pixelsHigh
        }
        
        NSGraphicsContext.restoreGraphicsState()
        return newRep
    }
    
    
    override func copy(with zone: NSZone? = nil) -> Any {
        let cursor = MACCursorSwift()
        cursor.frameCount = frameCount
        cursor.frameDuration = frameDuration
        cursor.size = size
        cursor.hotSpot = hotSpot
        cursor.identifier = identifier
        if let reps = representations as NSDictionary? {
            cursor.setValue(reps.mutableCopy(), forKey: "representations")
        }
        return cursor
    }
}
