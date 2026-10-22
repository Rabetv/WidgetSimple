import SwiftUI
import AppIntents

/// Where the canvas is drawn.
enum CanvasMode {
    /// On the Home Screen: every item is a tap target that launches its app.
    case widget(LaunchMethod)
    /// Inside the app: taps call back into the editor.
    case preview(onTap: ((LaunchItem) -> Void)?)
}

/// Draws a layout's items as plain text. Shared by the widget and the in-app preview
/// so what you design is exactly what appears on the Home Screen.
struct LauncherCanvas: View {
    let layout: LauncherLayout
    let mode: CanvasMode

    var body: some View {
        content
            .padding(.horizontal, CGFloat(layout.paddingH))
            .padding(.vertical, CGFloat(layout.paddingV))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: frameAlignment)
    }

    private var frameAlignment: Alignment {
        let h = layout.alignment.horizontal
        switch layout.verticalPosition {
        case .top: return Alignment(horizontal: h, vertical: .top)
        case .center, .spread: return Alignment(horizontal: h, vertical: .center)
        case .bottom: return Alignment(horizontal: h, vertical: .bottom)
        }
    }

    @ViewBuilder
    private var content: some View {
        if layout.items.isEmpty {
            Text(emptyText)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(layout.style.color.color.opacity(0.7))
        } else {
            switch layout.arrangement {
            case .grid: grid
            case .flow: flow
            }
        }
    }

    private var emptyText: String {
        if case .widget = mode { return "Open WidgetSimple to add apps" }
        return "Add apps below"
    }

    // MARK: Grid / list

    private var rows: [[LaunchItem]] {
        let cols = max(1, min(layout.columns, 6))
        return stride(from: 0, to: layout.items.count, by: cols).map {
            Array(layout.items[$0..<min($0 + cols, layout.items.count)])
        }
    }

    @ViewBuilder
    private var grid: some View {
        let cols = max(1, min(layout.columns, 6))
        let allRows = rows
        if layout.verticalPosition == .spread {
            VStack(spacing: 0) {
                ForEach(Array(allRows.enumerated()), id: \.offset) { index, row in
                    if index > 0 { Spacer(minLength: CGFloat(layout.rowSpacing)) }
                    gridRow(row, columns: cols)
                }
            }
            .frame(maxHeight: .infinity)
        } else {
            VStack(spacing: CGFloat(layout.rowSpacing)) {
                ForEach(Array(allRows.enumerated()), id: \.offset) { _, row in
                    gridRow(row, columns: cols)
                }
            }
        }
    }

    @ViewBuilder
    private func gridRow(_ row: [LaunchItem], columns: Int) -> some View {
        if columns == 1, let item = row.first {
            cell(item)
                .frame(maxWidth: .infinity, alignment: Alignment(horizontal: layout.alignment.horizontal, vertical: .center))
        } else {
            HStack(spacing: CGFloat(layout.columnSpacing)) {
                ForEach(0..<columns, id: \.self) { col in
                    Group {
                        if col < row.count {
                            cell(row[col])
                        } else {
                            Color.clear.frame(height: 1)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: Alignment(horizontal: layout.alignment.horizontal, vertical: .center))
                }
            }
        }
    }

    // MARK: Flow

    private var flow: some View {
        FlowLayout(spacing: layout.columnSpacing, lineSpacing: layout.rowSpacing, alignment: layout.alignment) {
            ForEach(layout.items) { item in
                cell(item)
            }
        }
    }

    // MARK: Cells

    @ViewBuilder
    private func cell(_ item: LaunchItem) -> some View {
        switch mode {
        case .widget(let method):
            if let url = item.target.url {
                if LaunchRouter.usesDirect(url, method: method) {
                    Button(intent: OpenTargetIntent(url: url)) {
                        ItemLabel(item: item, style: layout.style(for: item), alignment: layout.alignment)
                    }
                    .buttonStyle(.plain)
                } else {
                    Link(destination: LaunchRouter.hopURL(for: url)) {
                        ItemLabel(item: item, style: layout.style(for: item), alignment: layout.alignment)
                    }
                }
            } else {
                ItemLabel(item: item, style: layout.style(for: item), alignment: layout.alignment)
            }
        case .preview(let onTap):
            ItemLabel(item: item, style: layout.style(for: item), alignment: layout.alignment)
                .contentShape(Rectangle())
                .onTapGesture { onTap?(item) }
        }
    }
}

/// One launcher entry rendered as text (optionally with an SF Symbol).
struct ItemLabel: View {
    let item: LaunchItem
    let style: TextStyle
    var alignment: HAlignOption = .leading

    var body: some View {
        HStack(spacing: CGFloat(max(4, style.size * 0.3))) {
            if !item.symbol.isEmpty {
                Image(systemName: item.symbol)
                    .font(FontCatalog.font(for: style))
                    .foregroundStyle(style.color.color)
            }
            Text(style.textCase.apply(item.label.isEmpty ? " " : item.label))
                .font(FontCatalog.font(for: style))
                .tracking(CGFloat(style.tracking))
                .underline(style.underline)
                .foregroundStyle(style.color.color)
                .multilineTextAlignment(alignment.textAlignment)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.5)
        .shadow(color: style.shadow ? style.shadowColor.color : .clear,
                radius: style.shadow ? CGFloat(style.shadowRadius) : 0)
        .padding(.vertical, 2)
        .contentShape(Rectangle())
    }
}

/// Wraps items onto as many lines as needed, like words in a sentence.
struct FlowLayout: Layout {
    var spacing: CGFloat
    var lineSpacing: CGFloat
    var alignment: HAlignOption

    init(spacing: Double, lineSpacing: Double, alignment: HAlignOption) {
        self.spacing = CGFloat(spacing)
        self.lineSpacing = CGFloat(lineSpacing)
        self.alignment = alignment
    }

    private struct Line {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func computeLines(maxWidth: CGFloat, subviews: Subviews) -> ([Line], [CGSize]) {
        let sizes = subviews.map { sub -> CGSize in
            let s = sub.sizeThatFits(.unspecified)
            return CGSize(width: min(s.width, maxWidth), height: s.height)
        }
        var result: [Line] = []
        var current = Line()
        for (i, size) in sizes.enumerated() {
            let extra = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            if extra > maxWidth && !current.indices.isEmpty {
                result.append(current)
                current = Line()
                current.indices = [i]
                current.width = size.width
                current.height = size.height
            } else {
                current.indices.append(i)
                current.width = extra
                current.height = max(current.height, size.height)
            }
        }
        if !current.indices.isEmpty { result.append(current) }
        return (result, sizes)
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .greatestFiniteMagnitude
        let (lines, _) = computeLines(maxWidth: maxWidth, subviews: subviews)
        let height = lines.reduce(0) { $0 + $1.height } + lineSpacing * CGFloat(max(0, lines.count - 1))
        let widest = lines.map(\.width).max() ?? 0
        let width = maxWidth == .greatestFiniteMagnitude ? widest : maxWidth
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let (lines, sizes) = computeLines(maxWidth: bounds.width, subviews: subviews)
        var y = bounds.minY
        for line in lines {
            var x: CGFloat
            switch alignment {
            case .leading: x = bounds.minX
            case .center: x = bounds.minX + (bounds.width - line.width) / 2
            case .trailing: x = bounds.maxX - line.width
            }
            for i in line.indices {
                let size = sizes[i]
                subviews[i].place(at: CGPoint(x: x, y: y + (line.height - size.height) / 2),
                                  anchor: .topLeading,
                                  proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += line.height + lineSpacing
        }
    }
}
