import SwiftUI

private enum RowSelectionStyle {
    static let strokeWidth: CGFloat = 2
    static let cornerRadius: CGFloat = 8
    static let fillOpacity: Double = 0.08
    static let horizontalInset: CGFloat = 10
}

struct CursorThemeRowView: View {
    let cursorTheme: CursorThemeModel
    var isSelected: Bool = false

    @State private var preferenceRevision = 0

    private static let arrowIdentifiers = [
        "com.apple.coregraphics.Arrow",
        "com.apple.coregraphics.ArrowS",
    ]

    private var filteredCursors: [CursorModel] {
        _ = preferenceRevision
        if MACPreferences.hideTahoeCursors {
            return cursorTheme.cursors.filter {
                !MACConstants.hiddenCursorAliases.contains($0.identifier)
            }
        }
        return cursorTheme.cursors
    }

    private var heroCursor: CursorModel? {
        let cursors = filteredCursors
        for arrowId in Self.arrowIdentifiers {
            if let arrow = cursors.first(where: { $0.identifier == arrowId }) {
                return arrow
            }
        }
        return cursors.first
    }

    private static let secondaryIdentifiers = [
        "com.apple.coregraphics.IBeam",
        "com.apple.coregraphics.Copy",
        "com.apple.coregraphics.Move",
    ]

    private var secondaryCursors: [CursorModel] {
        let heroId = heroCursor?.id
        let candidates = filteredCursors.filter { $0.id != heroId }
        var result: [CursorModel] = []
        for id in Self.secondaryIdentifiers {
            if let match = candidates.first(where: { $0.identifier == id }) {
                result.append(match)
            }
        }
        for cursor in candidates where !result.contains(where: { $0.id == cursor.id }) {
            if result.count >= 3 { break }
            result.append(cursor)
        }
        return Array(result.prefix(3))
    }

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: cursorTheme.isApplied ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(cursorTheme.isApplied ? .green : .secondary.opacity(0.3))
                .font(.system(size: 14))

            if let hero = heroCursor {
                CursorThumbnailView(cursor: hero, size: 40)
            }

            HStack(spacing: 6) {
                Text(cursorTheme.name)
                    .font(.headline)
                    .lineLimit(1)

                if cursorTheme.isHiDPI {
                    Text("HD")
                        .font(.caption2.bold())
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(.blue.opacity(0.15))
                        .foregroundStyle(.blue)
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                }
            }

            Spacer()

            if !secondaryCursors.isEmpty {
                HStack(spacing: 6) {
                    ForEach(secondaryCursors) { cursor in
                        CursorThumbnailView(cursor: cursor, size: 28)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.quaternary)
                )
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, RowSelectionStyle.horizontalInset)
        .background(
            RoundedRectangle(cornerRadius: RowSelectionStyle.cornerRadius)
                .fill(isSelected ? Color.accentColor.opacity(RowSelectionStyle.fillOpacity) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: RowSelectionStyle.cornerRadius)
                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: RowSelectionStyle.strokeWidth)
        )
        .onReceive(NotificationCenter.default.publisher(for: .hideTahoeCursorsChanged)) { _ in
            preferenceRevision += 1
        }
    }
}
