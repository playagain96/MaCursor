import AppKit
import ImageIO
import UniformTypeIdentifiers

enum SlotImageImporter {
    static let maxFrameCount = 24
    static let minFrameDuration = 1.0 / 24.0

    struct AnimatedImport {
        let spriteSheet: NSBitmapImageRep
        let frameCount: Int
        let frameDuration: Double
    }

    enum ImportError: Error {
        case undecodable
        case compositionFailed
    }

    static func normalizedFileURL(_ url: URL) -> URL {
        (url as NSURL).filePathURL ?? url
    }

    private static let gifMagics = [Data("GIF87a".utf8), Data("GIF89a".utf8)]

    private static func magic(of url: URL, count: Int) -> Data? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        return try? handle.read(upToCount: count)
    }

    static func isGIF(_ url: URL) -> Bool {
        let url = normalizedFileURL(url)
        if url.pathExtension.lowercased() == "gif" { return true }
        guard let magic = magic(of: url, count: 6) else { return false }
        return gifMagics.contains(magic)
    }

    static func inferredScaleValue(forPixelWidth width: Int) -> UInt {
        CursorGeometry.scaleValue(forPixelWidth: width)
    }

    static func resized(_ rep: NSBitmapImageRep,
                        toPixelWidth width: Int,
                        frameCount: Int = 1) -> NSBitmapImageRep? {
        guard rep.pixelsWide > 0, rep.pixelsHigh > 0, width > 0 else { return nil }
        if rep.pixelsWide == width { return rep }
        guard let source = rep.cgImage else { return nil }

        let ratio = Double(width) / Double(rep.pixelsWide)
        let frames = max(1, frameCount)
        var height = Int((Double(rep.pixelsHigh) * ratio).rounded())
        if frames > 1 {
            let frameHeight = max(1, Int((Double(rep.pixelsHigh) * ratio / Double(frames)).rounded()))
            height = frameHeight * frames
        }
        guard height > 0 else { return nil }

        guard let ctx = try? ImageScaler.rgbaContext(width: width, height: height) else { return nil }
        ctx.draw(source, in: CGRect(x: 0, y: 0, width: width, height: height))
        guard let scaled = ctx.makeImage() else { return nil }
        return NSBitmapImageRep(cgImage: scaled)
    }

    static func normalized(_ rep: NSBitmapImageRep,
                           forScaleValue scale: UInt,
                           pointWidth: Int = CursorGeometry.basePointSize,
                           frameCount: Int = 1) -> NSBitmapImageRep {
        let target = CursorGeometry.pixelWidth(forScaleValue: scale, pointWidth: pointWidth)
        return resized(rep, toPixelWidth: target, frameCount: frameCount) ?? rep
    }

    static func importAnimatedGIF(from url: URL) throws -> AnimatedImport? {
        guard let source = CGImageSourceCreateWithURL(normalizedFileURL(url) as CFURL, nil) else {
            throw ImportError.undecodable
        }
        return try importAnimated(source: source)
    }

    static func importAnimatedGIF(from data: Data) throws -> AnimatedImport? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            throw ImportError.undecodable
        }
        return try importAnimated(source: source)
    }

    private static func importAnimated(source: CGImageSource) throws -> AnimatedImport? {
        let count = CGImageSourceGetCount(source)
        guard count > 0 else { throw ImportError.undecodable }
        guard count > 1 else { return nil }

        let delaysMS = (0..<count).map { index in
            max(1, Int((normalizedDelay(source: source, index: index) * 1000).rounded()))
        }
        let (frameIndices, frameDuration) = resampleTimeline(delaysMS: delaysMS)

        var decoded: [Int: CGImage] = [:]
        for index in Set(frameIndices) {
            guard let frame = CGImageSourceCreateImageAtIndex(source, index, nil) else {
                throw ImportError.undecodable
            }
            decoded[index] = frame
        }
        let frames = frameIndices.compactMap { decoded[$0] }
        let sheet = try composeSheet(frames: removingWhiteMatte(from: frames))
        return AnimatedImport(spriteSheet: sheet, frameCount: frames.count, frameDuration: frameDuration)
    }

    private static func normalizedDelay(source: CGImageSource, index: Int) -> Double {
        let properties = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any]
        let gif = properties?[kCGImagePropertyGIFDictionary] as? [CFString: Any]
        let unclamped = gif?[kCGImagePropertyGIFUnclampedDelayTime] as? Double
        let clamped = gif?[kCGImagePropertyGIFDelayTime] as? Double
        let delay = unclamped ?? clamped ?? 0.1
        return delay < 0.011 ? 0.1 : delay
    }

    private static func resampleTimeline(delaysMS: [Int]) -> ([Int], Double) {
        let total = delaysMS.reduce(0, +)
        if let restIndex = CursorThemeWriter.restFrameIndex(delays: delaysMS, total: total) {
            return ([restIndex], 1.0)
        }
        let count = delaysMS.count

        if count > maxFrameCount {
            let indices = (0..<maxFrameCount).map { $0 * count / maxFrameCount }
            return (indices, max(Double(total) / 1000.0 / Double(maxFrameCount), minFrameDuration))
        }

        let quarterMean = max(1, total / count / 4)
        let tick = max(delaysMS.reduce(0) { gcd($0, $1) }, quarterMean)
        let budget = min(maxFrameCount, max(count, total / tick))

        var allocations = delaysMS.map { max(1, $0 * budget / total) }
        var allocated = allocations.reduce(0, +)
        while allocated > budget {
            guard let index = allocations.indices
                .filter({ allocations[$0] > 1 })
                .max(by: { allocations[$0] < allocations[$1] }) else { break }
            allocations[index] -= 1
            allocated -= 1
        }
        if allocated < budget {
            let order = delaysMS.indices.sorted { lhs, rhs in
                let left = delaysMS[lhs] * budget % total
                let right = delaysMS[rhs] * budget % total
                return left == right ? lhs < rhs : left > right
            }
            var next = 0
            while allocated < budget {
                allocations[order[next % order.count]] += 1
                allocated += 1
                next += 1
            }
        }

        let indices = delaysMS.indices.flatMap { Array(repeating: $0, count: allocations[$0]) }
        let duration = max(Double(total) / 1000.0 / Double(indices.count), minFrameDuration)
        return (indices, duration)
    }

    private static func gcd(_ a: Int, _ b: Int) -> Int {
        var a = a
        var b = b
        while b != 0 {
            (a, b) = (b, a % b)
        }
        return a
    }

    private static let matteThreshold: UInt8 = 240

    private static func removingWhiteMatte(from frames: [CGImage]) -> [CGImage] {
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else { return frames }
        var buffers: [(ctx: CGContext, data: UnsafeMutablePointer<UInt8>, width: Int, height: Int)] = []
        for frame in frames {
            let width = frame.width
            let height = frame.height
            guard let ctx = CGContext(data: nil, width: width, height: height,
                                      bitsPerComponent: 8, bytesPerRow: width * 4,
                                      space: colorSpace,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
                  let raw = ctx.data else { return frames }
            ctx.draw(frame, in: CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height)))
            buffers.append((ctx, raw.assumingMemoryBound(to: UInt8.self), width, height))
        }

        for buffer in buffers {
            for index in 0..<(buffer.width * buffer.height) where buffer.data[index * 4 + 3] < 255 {
                return frames
            }
        }
        for buffer in buffers {
            let cornerIndices = [0, buffer.width - 1,
                                 (buffer.height - 1) * buffer.width,
                                 buffer.height * buffer.width - 1]
            for corner in cornerIndices {
                let p = corner * 4
                guard buffer.data[p] >= matteThreshold,
                      buffer.data[p + 1] >= matteThreshold,
                      buffer.data[p + 2] >= matteThreshold else { return frames }
            }
        }

        var keyed: [CGImage] = []
        for buffer in buffers {
            floodKeyWhite(data: buffer.data, width: buffer.width, height: buffer.height)
            guard let image = buffer.ctx.makeImage() else { return frames }
            keyed.append(image)
        }
        return keyed
    }

    private static func floodKeyWhite(data: UnsafeMutablePointer<UInt8>, width: Int, height: Int) {
        var visited = [Bool](repeating: false, count: width * height)
        var stack = [Int]()
        func seed(_ index: Int) {
            guard !visited[index] else { return }
            let p = index * 4
            guard data[p] >= matteThreshold,
                  data[p + 1] >= matteThreshold,
                  data[p + 2] >= matteThreshold else { return }
            visited[index] = true
            stack.append(index)
        }
        for x in 0..<width {
            seed(x)
            seed((height - 1) * width + x)
        }
        for y in 0..<height {
            seed(y * width)
            seed(y * width + width - 1)
        }
        while let index = stack.popLast() {
            let p = index * 4
            data[p] = 0
            data[p + 1] = 0
            data[p + 2] = 0
            data[p + 3] = 0
            let x = index % width
            if x > 0 { seed(index - 1) }
            if x < width - 1 { seed(index + 1) }
            if index >= width { seed(index - width) }
            if index < (height - 1) * width { seed(index + width) }
        }
    }

    private static func composeSheet(frames: [CGImage]) throws -> NSBitmapImageRep {
        guard let first = frames.first else { throw ImportError.compositionFailed }
        let width = first.width
        let height = first.height
        guard frames.allSatisfy({ $0.width == width && $0.height == height }) else {
            throw ImportError.compositionFailed
        }
        guard let ctx = try? ImageScaler.rgbaContext(width: width, height: height * frames.count) else {
            throw ImportError.compositionFailed
        }
        for (index, frame) in frames.enumerated() {
            let y = CGFloat((frames.count - 1 - index) * height)
            ctx.draw(frame, in: CGRect(x: 0, y: y, width: CGFloat(width), height: CGFloat(height)))
        }
        guard let sheet = ctx.makeImage() else { throw ImportError.compositionFailed }
        return NSBitmapImageRep(cgImage: sheet)
    }
}
