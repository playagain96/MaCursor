import AppKit

struct WindowsCursorImporter {


    static func importCUR(from url: URL) throws -> MACCursorSwift {
        let data = try Data(contentsOf: url)
        let parsed = try WindowsCursorParser.parseCUR(data)
        return buildCursor(from: parsed, filename: url.deletingPathExtension().lastPathComponent)
    }

    static func importANI(from url: URL) throws -> MACCursorSwift {
        let data = try Data(contentsOf: url)
        let parsed = try WindowsCursorParser.parseANI(data)
        return buildAnimatedCursor(from: parsed, filename: url.deletingPathExtension().lastPathComponent)
    }

    static func importFile(from url: URL) throws -> MACCursorSwift {
        let data = try Data(contentsOf: url)
        let type = WindowsCursorParser.fileType(of: data)

        switch type {
        case .cur:
            let parsed = try WindowsCursorParser.parseCUR(data)
            return buildCursor(from: parsed, filename: url.deletingPathExtension().lastPathComponent)
        case .ani:
            let parsed = try WindowsCursorParser.parseANI(data)
            return buildAnimatedCursor(from: parsed, filename: url.deletingPathExtension().lastPathComponent)
        case .unknown:
            throw WindowsCursorParser.ParseError.unsupportedFormat("Not a .cur or .ani file")
        }
    }


    static func importAsTheme(from urls: [URL], themeName: String? = nil) -> CursorLibrary {
        let library = CursorLibrary()

        let resolvedName: String
        if let name = themeName, !name.isEmpty {
            resolvedName = name
        } else if urls.count == 1 {
            resolvedName = urls[0].deletingPathExtension().lastPathComponent
        } else {
            let folder = urls[0].deletingLastPathComponent().lastPathComponent
            resolvedName = folder.isEmpty ? "Imported Cursors" : folder
        }

        library.undoManager.disableUndoRegistration()
        library.name = resolvedName
        library.identifier = CursorLibrary.generateIdentifier(from: resolvedName)
        library.undoManager.enableUndoRegistration()

        for url in urls {
            do {
                let cursor = try importFile(from: url)
                library.addCursor(cursor)
            } catch {
                NSLog("WindowsCursorImporter: Failed to import \(url.lastPathComponent): \(error.localizedDescription)")
            }
        }

        return library
    }


    static func parseForRepresentation(from url: URL) throws -> (image: NSBitmapImageRep, hotspot: CGPoint, frameCount: Int, frameDuration: Double) {
        let data = try Data(contentsOf: url)
        let type = WindowsCursorParser.fileType(of: data)

        switch type {
        case .cur:
            let parsed = try WindowsCursorParser.parseCUR(data)
            guard let best = parsed.images.first else {
                throw WindowsCursorParser.ParseError.corruptedImageData("No images in CUR file")
            }
            return (best.image, best.hotspot, 1, 1.0)

        case .ani:
            let parsed = try WindowsCursorParser.parseANI(data)
            let result = buildSpriteSheet(from: parsed)
            return (result.spriteSheet, result.hotspot, result.frameCount, result.frameDuration)

        case .unknown:
            throw WindowsCursorParser.ParseError.unsupportedFormat("Not a .cur or .ani file")
        }
    }


    private static func buildCursor(from parsed: WindowsCursorParser.CursorData, filename: String) -> MACCursorSwift {
        let cursor = MACCursorSwift()
        cursor.identifier = ""
        cursor.frameCount = 1
        cursor.frameDuration = 1.0

        let (entry1x, entry2x) = selectBestRepresentations(from: parsed.images)

        guard let baseEntry = entry1x ?? entry2x else {
            cursor.hotSpot = NSPoint(x: parsed.hotspot.x, y: parsed.hotspot.y)
            return cursor
        }

        let base = baseEntry.image
        let size = CursorGeometry.baseSize(matchingAspectOf: base, frameCount: 1)
        cursor.size = size
        let pointWidth = CursorGeometry.normalizedPointWidth(size.width)
        let hotSpotScale = base.pixelsWide > 0 ? size.width / CGFloat(base.pixelsWide) : 1

        cursor.hotSpot = NSPoint(x: baseEntry.hotspot.x * hotSpotScale,
                                 y: baseEntry.hotspot.y * hotSpotScale)

        if let rep = entry1x?.image {
            cursor.setRepresentation(
                SlotImageImporter.normalized(rep, forScaleValue: 100, pointWidth: pointWidth),
                for: .scale100)
        }

        if let rep = entry2x?.image {
            cursor.setRepresentation(
                SlotImageImporter.normalized(rep, forScaleValue: 200, pointWidth: pointWidth),
                for: .scale200)
        }

        return cursor
    }


    private static func buildAnimatedCursor(from parsed: WindowsCursorParser.AnimatedCursorData, filename: String) -> MACCursorSwift {
        let cursor = MACCursorSwift()
        cursor.identifier = ""

        let result = buildSpriteSheet(from: parsed)

        cursor.frameCount = UInt(result.frameCount)
        cursor.frameDuration = result.frameDuration

        let size = CursorGeometry.baseSize(matchingAspectOf: result.spriteSheet,
                                           frameCount: result.frameCount)
        cursor.size = size
        let pointWidth = CursorGeometry.normalizedPointWidth(size.width)
        let hotSpotScale = result.spriteSheet.pixelsWide > 0
            ? size.width / CGFloat(result.spriteSheet.pixelsWide)
            : 1

        cursor.hotSpot = NSPoint(x: result.hotspot.x * hotSpotScale,
                                 y: result.hotspot.y * hotSpotScale)

        cursor.setRepresentation(
            SlotImageImporter.normalized(result.spriteSheet, forScaleValue: 100,
                                         pointWidth: pointWidth,
                                         frameCount: result.frameCount),
            for: .scale100)

        if let sheet2x = result.spriteSheet2x {
            cursor.setRepresentation(
                SlotImageImporter.normalized(sheet2x, forScaleValue: 200,
                                             pointWidth: pointWidth,
                                             frameCount: result.frameCount),
                for: .scale200)
        }

        return cursor
    }

    private struct SpriteSheetResult {
        let spriteSheet: NSBitmapImageRep
        let spriteSheet2x: NSBitmapImageRep?
        let hotspot: CGPoint
        let frameCount: Int
        let frameDuration: Double
        let frameSize: NSSize
    }

    private static func buildSpriteSheet(from parsed: WindowsCursorParser.AnimatedCursorData) -> SpriteSheetResult {
        let orderedFrames: [WindowsCursorParser.CursorData]
        if let seq = parsed.sequence {
            var byOrdinal: [Int: WindowsCursorParser.CursorData] = [:]
            for (index, ordinal) in parsed.frameOrdinals.enumerated()
            where parsed.frames.indices.contains(index) {
                byOrdinal[ordinal] = parsed.frames[index]
            }
            orderedFrames = seq.compactMap { byOrdinal[$0] }
        } else {
            orderedFrames = parsed.frames
        }

        guard !orderedFrames.isEmpty else {
            return SpriteSheetResult(
                spriteSheet: blankRepresentation(), spriteSheet2x: nil, hotspot: .zero,
                frameCount: 1, frameDuration: 1.0,
                frameSize: NSSize(width: 1, height: 1)
            )
        }

        var frameReps: [NSBitmapImageRep] = []
        var frameReps2x: [NSBitmapImageRep] = []
        var baseEntries: [WindowsCursorParser.CursorData.ImageEntry] = []
        for frame in orderedFrames {
            let (entry1x, entry2x) = selectBestRepresentations(from: frame.images)
            if let e = entry1x {
                frameReps.append(e.image)
                baseEntries.append(e)
            }
            if let e = entry2x { frameReps2x.append(e.image) }
        }

        guard !frameReps.isEmpty else {
            return SpriteSheetResult(
                spriteSheet: blankRepresentation(), spriteSheet2x: nil, hotspot: .zero,
                frameCount: 1, frameDuration: 1.0,
                frameSize: NSSize(width: 1, height: 1)
            )
        }

        let spriteSheet = composeSpriteSheet(frames: frameReps)

        let spriteSheet2x: NSBitmapImageRep?
        if frameReps2x.count == frameReps.count {
            spriteSheet2x = composeSpriteSheet(frames: frameReps2x)
        } else {
            spriteSheet2x = nil
        }

        let hotspot = baseEntries.first?.hotspot ?? orderedFrames[0].hotspot

        let frameWidth = frameReps[0].pixelsWide
        let frameHeight = frameReps[0].pixelsHigh

        let frameDuration: Double
        if let rates = parsed.perFrameRates, !rates.isEmpty {
            frameDuration = rates.reduce(0, +) / Double(rates.count)
        } else {
            frameDuration = parsed.frameRate
        }

        return SpriteSheetResult(
            spriteSheet: spriteSheet,
            spriteSheet2x: spriteSheet2x,
            hotspot: hotspot,
            frameCount: frameReps.count,
            frameDuration: max(frameDuration, 0.01),
            frameSize: NSSize(width: frameWidth, height: frameHeight)
        )
    }

    private static func composeSpriteSheet(frames: [NSBitmapImageRep]) -> NSBitmapImageRep {
        guard let first = frames.first else { return blankRepresentation() }
        if frames.count == 1 { return first.canonicalRGBA }

        let width = first.pixelsWide
        let frameHeight = first.pixelsHigh
        guard width > 0, frameHeight > 0,
              let ctx = try? ImageScaler.rgbaContext(width: width,
                                                     height: frameHeight * frames.count)
        else {
            return MACCursorSwift.composeRepresentation(withFrames: frames) ?? first
        }

        let uniform = frames.allSatisfy { $0.pixelsWide == width && $0.pixelsHigh == frameHeight }
        ctx.interpolationQuality = uniform ? .none : .high

        for (index, frame) in frames.enumerated() {
            guard let image = frame.cgImage else { continue }
            let y = CGFloat((frames.count - 1 - index) * frameHeight)
            ctx.draw(image, in: CGRect(x: 0, y: y,
                                       width: CGFloat(width), height: CGFloat(frameHeight)))
        }

        guard let sheet = ctx.makeImage() else {
            return MACCursorSwift.composeRepresentation(withFrames: frames) ?? first
        }
        return NSBitmapImageRep(cgImage: sheet).canonicalRGBA
    }

    private static func blankRepresentation() -> NSBitmapImageRep {
        NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: 1, pixelsHigh: 1,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
            isPlanar: false, colorSpaceName: .deviceRGB,
            bytesPerRow: 4, bitsPerPixel: 32
        )!
    }


    private static func selectBestRepresentations(
        from images: [WindowsCursorParser.CursorData.ImageEntry]
    ) -> (entry1x: WindowsCursorParser.CursorData.ImageEntry?,
          entry2x: WindowsCursorParser.CursorData.ImageEntry?) {
        guard !images.isEmpty else { return (nil, nil) }

        let img32 = images.first { $0.width == 32 && $0.height == 32 }
        let img64 = images.first { $0.width == 64 && $0.height == 64 }

        let usable = images.filter { $0.width > 16 || $0.height > 16 }

        if let img32 {
            return (img32, img64)
        }
        if let first = usable.first {
            return (first, nil)
        }
        return (images.first, nil)
    }
}
