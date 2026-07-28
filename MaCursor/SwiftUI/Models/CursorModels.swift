import CoreGraphics
import Foundation

public struct PixelSize: Hashable, Sendable, CustomStringConvertible {
    public let width: Int
    public let height: Int

    public init(width: Int, height: Int) {
        self.width = width
        self.height = height
    }

    public init(square side: Int) {
        self.init(width: side, height: side)
    }

    public var area: Int { width * height }
    public var isSquare: Bool { width == height }
    public var description: String { "\(width)x\(height)" }
}

public struct CursorImage: @unchecked Sendable {
    public let image: CGImage
    public let hotspot: CGPoint

    public var size: PixelSize { PixelSize(width: image.width, height: image.height) }

    public init(image: CGImage, hotspot: CGPoint) throws {
        guard hotspot.x >= 0, hotspot.y >= 0,
              Int(hotspot.x) < image.width, Int(hotspot.y) < image.height else {
            throw ModelError.invalidHotspot(x: hotspot.x, y: hotspot.y,
                                            width: image.width, height: image.height)
        }
        self.image = image
        self.hotspot = hotspot
    }
}

public struct Cursor: Sendable {
    public private(set) var images: [PixelSize: CursorImage]

    public init() {
        self.images = [:]
    }

    public init(_ images: some Sequence<CursorImage>) {
        self.images = [:]
        for image in images { add(image) }
    }

    public mutating func add(_ image: CursorImage) {
        images[image.size] = image
    }

    public subscript(size: PixelSize) -> CursorImage? {
        images[size]
    }

    public var isEmpty: Bool { images.isEmpty }

    public var sizes: [PixelSize] {
        images.keys.sorted { ($0.area, $0.width) < ($1.area, $1.width) }
    }

    public var largestSize: PixelSize? {
        images.keys.max { ($0.area, $0.width) < ($1.area, $1.width) }
    }

    public static func bestSourceSize(for target: PixelSize,
                                      among sizes: [PixelSize]) -> PixelSize? {
        let covering = sizes.filter { $0.width >= target.width && $0.height >= target.height }
        return covering.min { ($0.area, $0.width) < ($1.area, $1.width) }
            ?? sizes.max { ($0.area, $0.width) < ($1.area, $1.width) }
    }

    public func bestSourceSize(for target: PixelSize) -> PixelSize? {
        Self.bestSourceSize(for: target, among: Array(images.keys))
    }

    static func rescaled(_ source: CursorImage, to size: PixelSize) throws -> CursorImage {
        let sourceSize = source.size
        let xRatio = Double(size.width) / Double(sourceSize.width)
        let yRatio = Double(size.height) / Double(sourceSize.height)
        let finalW: Double, finalH: Double, wOff: Double, hOff: Double
        if xRatio <= yRatio {
            finalW = Double(size.width)
            wOff = 0
            finalH = Double(sourceSize.height) / Double(sourceSize.width) * finalW
            hOff = (Double(size.height) - finalH) / 2
        } else {
            finalH = Double(size.height)
            hOff = 0
            finalW = Double(sourceSize.width) / Double(sourceSize.height) * finalH
            wOff = (Double(size.width) - finalW) / 2
        }
        let scaled = try ImageScaler.padScale(source.image, to: size)
        let hx = (wOff + source.hotspot.x / Double(sourceSize.width) * finalW).rounded(.down)
        let hy = (hOff + source.hotspot.y / Double(sourceSize.height) * finalH).rounded(.down)
        let hotspot = CGPoint(x: min(max(hx, 0), Double(size.width - 1)),
                              y: min(max(hy, 0), Double(size.height - 1)))
        return try CursorImage(image: scaled, hotspot: hotspot)
    }

    public mutating func synthesizeSizes(_ newSizes: [PixelSize]) throws {
        let nativeSizes = Array(images.keys)
        guard !nativeSizes.isEmpty else { throw ModelError.emptyCursor }
        for size in newSizes where images[size] == nil {
            guard let sourceSize = Self.bestSourceSize(for: size, among: nativeSizes),
                  let source = images[sourceSize] else { throw ModelError.emptyCursor }
            add(try Self.rescaled(source, to: size))
        }
    }

    public func normalizedToStandardScales() throws
        -> (cursor: Cursor, changed: Bool, dropped: [PixelSize]) {
        guard !images.isEmpty else { return (self, false, []) }
        let standard = EditorScale.allCases.map(\.pixelSize)
        var assigned: [PixelSize: CursorImage] = [:]
        var foreign: [CursorImage] = []
        for (size, image) in images {
            if standard.contains(size) {
                assigned[size] = image
            } else {
                foreign.append(image)
            }
        }
        var changed = false
        var dropped: [PixelSize] = []
        for image in foreign.sorted(by: {
            ($0.size.area, $0.size.width) > ($1.size.area, $1.size.width)
        }) {
            changed = true
            let target = standard.last { candidate in
                assigned[candidate] == nil
                    && candidate.width <= image.size.width
                    && candidate.height <= image.size.height
            }
            guard let target else {
                dropped.append(image.size)
                continue
            }
            assigned[target] = try Self.rescaled(image, to: target)
        }
        guard !assigned.isEmpty else {
            let used = bestSourceSize(for: standard[0])
            var floor = self
            try floor.keepOnlySizes([standard[0]])
            let floorDropped = images.keys.filter { $0 != used }
                .sorted { ($0.area, $0.width) < ($1.area, $1.width) }
            return (floor, true, floorDropped)
        }
        return (Cursor(assigned.values), changed,
                dropped.sorted { ($0.area, $0.width) < ($1.area, $1.width) })
    }

    public mutating func keepOnlySizes(_ keep: [PixelSize]) throws {
        try synthesizeSizes(keep)
        let keepSet = Set(keep)
        images = images.filter { keepSet.contains($0.key) }
    }

    public mutating func keepSquareSizesOnly() {
        images = images.filter { $0.key.isSquare }
    }

    public mutating func remove(_ size: PixelSize) {
        images[size] = nil
    }
}

public struct AnimatedCursor: Sendable {
    public struct Frame: Sendable {
        public var cursor: Cursor
        public var delayMS: Int

        public init(cursor: Cursor, delayMS: Int) {
            self.cursor = cursor
            self.delayMS = delayMS
        }
    }

    public var frames: [Frame]

    public init(frames: [Frame] = []) {
        self.frames = frames
    }

    public init(cursors: [Cursor], delaysMS: [Int]) {
        self.frames = zip(cursors, delaysMS).map { Frame(cursor: $0.0, delayMS: $0.1) }
    }

    public var isAnimated: Bool { frames.count > 1 }

    public func contentEquals(_ other: AnimatedCursor) -> Bool {
        guard frames.count == other.frames.count else { return false }
        for (a, b) in zip(frames, other.frames) {
            guard a.delayMS == b.delayMS, a.cursor.sizes == b.cursor.sizes else { return false }
            for size in a.cursor.sizes {
                guard let ia = a.cursor[size], let ib = b.cursor[size],
                      ia.hotspot == ib.hotspot,
                      Self.pixelsEqual(ia.image, ib.image) else { return false }
            }
        }
        return true
    }

    private static func pixelsEqual(_ a: CGImage, _ b: CGImage) -> Bool {
        if a === b { return true }
        guard a.width == b.width, a.height == b.height,
              let da = a.dataProvider?.data, let db = b.dataProvider?.data else { return false }
        return (da as Data) == (db as Data)
    }

    public mutating func normalize(addingSizes extra: [PixelSize] = []) throws {
        var union = Set(extra)
        for frame in frames {
            union.formUnion(frame.cursor.images.keys)
        }
        let sizes = Array(union)
        for index in frames.indices {
            try frames[index].cursor.synthesizeSizes(sizes)
        }
    }

    public mutating func keepOnlySizes(_ keep: [PixelSize]) throws {
        for index in frames.indices {
            try frames[index].cursor.keepOnlySizes(keep)
        }
    }

    public mutating func keepSquareSizesOnly() {
        for index in frames.indices {
            frames[index].cursor.keepSquareSizesOnly()
        }
    }

    public func normalizedToStandardScales() throws
        -> (cursor: AnimatedCursor, changed: Bool, dropped: [PixelSize]) {
        var changed = false
        var dropped = Set<PixelSize>()
        var perFrame: [Cursor] = []
        for frame in frames {
            let result = try frame.cursor.normalizedToStandardScales()
            perFrame.append(result.cursor)
            if result.changed { changed = true }
            dropped.formUnion(result.dropped)
        }
        var union = Set(perFrame.flatMap { Array($0.images.keys) })
        for size in union.sorted(by: { ($0.area, $0.width) > ($1.area, $1.width) }) {
            let unavailable = perFrame.contains { cursor in
                guard !cursor.isEmpty, cursor[size] == nil else { return false }
                guard let largest = cursor.largestSize else { return true }
                return largest.width < size.width || largest.height < size.height
            }
            if unavailable {
                union.remove(size)
                dropped.insert(size)
            }
        }
        let keep = union.sorted { ($0.area, $0.width) < ($1.area, $1.width) }
        var normalizedFrames: [Frame] = []
        for (index, frame) in frames.enumerated() {
            var cursor = perFrame[index]
            if !cursor.isEmpty, !keep.isEmpty, Set(cursor.images.keys) != union {
                try cursor.keepOnlySizes(keep)
                changed = true
            }
            normalizedFrames.append(Frame(cursor: cursor, delayMS: frame.delayMS))
        }
        return (AnimatedCursor(frames: normalizedFrames), changed,
                dropped.sorted { ($0.area, $0.width) < ($1.area, $1.width) })
    }
}

public struct ThemeIdentity: Sendable, Equatable {
    public let identifier: String
    public let uuid: String
    public let version: Double

    public init(identifier: String, uuid: String, version: Double = 1.0) {
        self.identifier = identifier
        self.uuid = uuid
        self.version = version
    }
}
