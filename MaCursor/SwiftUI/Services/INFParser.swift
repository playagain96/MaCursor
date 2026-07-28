import Foundation

public struct INFScheme: Sendable, Equatable {
    public var schemeName: String?
    public var roleFiles: [String: String]

    public init(schemeName: String? = nil, roleFiles: [String: String] = [:]) {
        self.schemeName = schemeName
        self.roleFiles = roleFiles
    }
}

public enum INFParser {
    public static let registryOrder: [String] = [
        "pointer", "help", "work", "busy", "cross", "text", "hand",
        "unavailiable", "vert", "horz", "dgn1", "dgn2", "move", "alternate", "link",
    ]

    private static let roleSet: Set<String> = Set(registryOrder).union(["unavailable"])

    public static func parse(_ data: Data) -> INFScheme {
        let text = decode(data)
        var strings: [String: String] = [:]
        var registryLine: String?

        var section = ""
        for rawLine in text.split(omittingEmptySubsequences: false,
                                  whereSeparator: { $0 == "\n" || $0 == "\r\n" }) {
            let line = stripComment(String(rawLine)).trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty else { continue }
            if line.hasPrefix("["), let close = line.firstIndex(of: "]") {
                section = String(line[line.index(after: line.startIndex) ..< close]).lowercased()
                continue
            }
            switch section {
            case "strings":
                guard let eq = line.firstIndex(of: "=") else { continue }
                let key = String(line[..<eq]).trimmingCharacters(in: .whitespaces).lowercased()
                let value = unquote(String(line[line.index(after: eq)...]))
                strings[key] = value
            case "scheme.reg":
                if line.lowercased().contains("control panel\\cursors\\schemes") {
                    registryLine = line
                }
            default:
                break
            }
        }

        var scheme = INFScheme(schemeName: strings["scheme_name"])

        if let registryLine {
            let fields = quotedFields(registryLine)
            if scheme.schemeName?.isEmpty ?? true, fields.count >= 2 {
                let candidate = expandVariables(fields[1], strings: strings)
                    .trimmingCharacters(in: .whitespaces)
                if !candidate.isEmpty { scheme.schemeName = candidate }
            }
            if fields.count >= 3, let csv = fields.last {
                let items = csv.components(separatedBy: ",")
                for (index, rawItem) in items.enumerated() where index < registryOrder.count {
                    let expanded = expandVariables(rawItem, strings: strings)
                        .trimmingCharacters(in: .whitespaces)
                    guard !expanded.isEmpty else { continue }
                    let fileName = lastPathComponent(expanded)
                    guard !fileName.isEmpty else { continue }
                    scheme.roleFiles[registryOrder[index]] = fileName
                }
            }
        }

        for (key, value) in strings where roleSet.contains(key) {
            let role = key == "unavailable" ? "unavailiable" : key
            let fileName = lastPathComponent(value)
            if scheme.roleFiles[role] == nil, !fileName.isEmpty,
               fileName.lowercased().hasSuffix(".cur") || fileName.lowercased().hasSuffix(".ani") {
                scheme.roleFiles[role] = fileName
            }
        }

        return scheme
    }

    private static func decode(_ data: Data) -> String {
        if data.starts(with: [0xFF, 0xFE]) {
            return String(data: data.dropFirst(2), encoding: .utf16LittleEndian) ?? ""
        }
        if data.starts(with: [0xFE, 0xFF]) {
            return String(data: data.dropFirst(2), encoding: .utf16BigEndian) ?? ""
        }
        if data.starts(with: [0xEF, 0xBB, 0xBF]) {
            let body = data.dropFirst(3)
            if let utf8 = String(data: body, encoding: .utf8) { return utf8 }
            return decodeLegacy(Data(body))
        }
        if let utf16 = decodeBOMlessUTF16(data) { return utf16 }
        if let utf8 = String(data: data, encoding: .utf8) { return utf8 }
        return decodeLegacy(data)
    }

    private static func decodeBOMlessUTF16(_ data: Data) -> String? {
        guard data.count >= 16, data.count.isMultiple(of: 2) else { return nil }
        let sample = data.prefix(256)
        var evenNulls = 0, oddNulls = 0
        for (offset, byte) in sample.enumerated() where byte == 0 {
            if offset.isMultiple(of: 2) { evenNulls += 1 } else { oddNulls += 1 }
        }
        let threshold = sample.count / 4
        if oddNulls >= threshold, oddNulls > evenNulls {
            return String(data: data, encoding: .utf16LittleEndian)
        }
        if evenNulls >= threshold, evenNulls > oddNulls {
            return String(data: data, encoding: .utf16BigEndian)
        }
        return nil
    }

    private static func decodeLegacy(_ data: Data) -> String {
        var converted: NSString?
        let hints = legacyEncodingHints.map { NSNumber(value: $0) }
        let detected = NSString.stringEncoding(
            for: data,
            encodingOptions: [.suggestedEncodingsKey: hints],
            convertedString: &converted,
            usedLossyConversion: nil)
        if detected != 0, let text = converted as String? { return text }
        return String(data: data, encoding: .isoLatin1) ?? ""
    }

    private static func cfEncoding(_ value: CFStringEncodings) -> String.Encoding {
        String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(
            CFStringEncoding(value.rawValue)))
    }

    private static let legacyEncodingHints: [UInt] = [
        cfEncoding(.GB_18030_2000), cfEncoding(.GBK_95), cfEncoding(.big5),
        cfEncoding(.dosJapanese), cfEncoding(.EUC_KR),
        .windowsCP1252, .isoLatin1,
    ].map(\.rawValue)

    private static func stripComment(_ line: String) -> String {
        var inQuotes = false
        for index in line.indices {
            let ch = line[index]
            if ch == "\"" { inQuotes.toggle() }
            if ch == ";", !inQuotes { return String(line[..<index]) }
        }
        return line
    }

    private static func unquote(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        if trimmed.count >= 2, trimmed.hasPrefix("\""), trimmed.hasSuffix("\"") {
            return String(trimmed.dropFirst().dropLast())
        }
        return trimmed
    }

    private static func quotedFields(_ line: String) -> [String] {
        var fields: [String] = []
        var current = ""
        var inQuotes = false
        for ch in line {
            if ch == "\"" {
                if inQuotes { fields.append(current); current = "" }
                inQuotes.toggle()
            } else if inQuotes {
                current.append(ch)
            }
        }
        return fields
    }

    private static func expandVariables(_ item: String, strings: [String: String]) -> String {
        var out = ""
        var rest = Substring(item)
        while let start = rest.firstIndex(of: "%") {
            out += rest[..<start]
            let afterStart = rest.index(after: start)
            guard let end = rest[afterStart...].firstIndex(of: "%") else {
                out += rest[start...]
                return out
            }
            let name = String(rest[afterStart ..< end]).lowercased()
            out += strings[name] ?? ""
            rest = rest[rest.index(after: end)...]
        }
        out += rest
        return out
    }

    private static func lastPathComponent(_ path: String) -> String {
        path.split(whereSeparator: { $0 == "\\" || $0 == "/" }).last.map(String.init) ?? path
    }
}
