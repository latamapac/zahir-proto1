import SwiftUI

// Results: what happened, read plainly. A summary of four figures, a table
// of every creative sortable by whatever matters right now, and the three
// things Figaro learned from it — each one ready to remember or act on.

private enum SortKey: String { case title, channel, spend, clicks, ctr, cpa }

struct ResultsSurface: View {
    @ObservedObject var store = ZahirStore.shared

    @State private var range = "7 days"
    @State private var channel = "All"
    @State private var sortKey: SortKey = .clicks
    @State private var descending = true

    private static let ranges = ["7 days", "30 days", "90 days"]
    private static let channels = ["All", "Instagram", "Meta Ads", "LinkedIn", "TikTok"]

    private var filtered: [ZResult] {
        channel == "All" ? store.results : store.results.filter { $0.channel == channel }
    }

    private var sorted: [ZResult] {
        filtered.sorted { a, b in
            let ascending: Bool
            switch sortKey {
            case .title: ascending = a.title < b.title
            case .channel: ascending = a.channel < b.channel
            case .spend: ascending = a.spend < b.spend
            case .clicks: ascending = a.clicks < b.clicks
            case .ctr: ascending = a.ctr < b.ctr
            case .cpa: ascending = a.cpa < b.cpa
            }
            return descending ? !ascending : ascending
        }
    }

    private var bestID: ZResult.ID? { filtered.count >= 2 ? filtered.max(by: { $0.ctr < $1.ctr })?.id : nil }
    private var worstID: ZResult.ID? { filtered.count >= 2 ? filtered.min(by: { $0.ctr < $1.ctr })?.id : nil }

    private var subtitle: String {
        channel == "All"
            ? "Last \(range) across Instagram, Meta Ads, LinkedIn and TikTok."
            : "Last \(range) on \(channel)."
    }

    var body: some View {
        SurfacePage(title: "Results", line: subtitle) {
            Flow(spacing: 8, line: 8) {
                ForEach(Self.ranges, id: \.self) { r in
                    Choice(text: r, on: r == range) { withAnimation(Motion.quick) { range = r } }
                }
                ForEach(Self.channels, id: \.self) { c in
                    Choice(text: c, on: c == channel) { withAnimation(Motion.quick) { channel = c } }
                }
                PrimaryButton(title: "Turn the best into a brief", action: createBrief)
            }
            .frame(maxWidth: 620, alignment: .trailing)
        } content: {
            VStack(alignment: .leading, spacing: 32) {
                summary
                creatives
                learned
            }
        }
    }

    // MARK: Summary

    private var summary: some View {
        HStack(spacing: 0) {
            PlainFigure(label: "Spend", value: money(Double(totalSpend)), meaning: "Up 12% on last week.")
            divider
            PlainFigure(label: "Clicks", value: "\(totalClicks)", meaning: "About the same as last week.")
            divider
            PlainFigure(label: "Click rate", value: filtered.isEmpty ? "—" : String(format: "%.1f%%", avgCTR), meaning: "Down a little on last week.")
            divider
            PlainFigure(label: "Cost per sale", value: filtered.isEmpty ? "—" : money(avgCPA, cents: true), meaning: "The cheapest it's been this month.")
        }
        .zCard()
    }

    private var divider: some View {
        Rectangle().fill(Palette.hairline).frame(width: 1).padding(.vertical, 6)
    }

    private var totalSpend: Int { filtered.reduce(0) { $0 + $1.spend } }
    private var totalClicks: Int { filtered.reduce(0) { $0 + $1.clicks } }
    private var avgCTR: Double { filtered.isEmpty ? 0 : filtered.reduce(0.0) { $0 + $1.ctr } / Double(filtered.count) }
    private var avgCPA: Double { filtered.isEmpty ? 0 : filtered.reduce(0.0) { $0 + $1.cpa } / Double(filtered.count) }

    // MARK: Creatives

    private var creatives: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHead(title: "Creatives", line: "Click a column to sort.")
            if sorted.isEmpty {
                EmptyState(symbol: "chart.bar", title: "Nothing here yet",
                           line: "Figaro hasn't run anything on \(channel) in the last \(range).")
                    .zCard()
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    tableHeader
                    Rectangle().fill(Palette.hairline).frame(height: 1)
                    ForEach(Array(sorted.enumerated()), id: \.element.id) { index, result in
                        VStack(alignment: .leading, spacing: 0) {
                            CreativeRow(result: result, tag: tag(for: result)).padding(.vertical, 12)
                            if index < sorted.count - 1 {
                                Rectangle().fill(Palette.hairline).frame(height: 1)
                            }
                        }
                    }
                }
                .zCard()
            }
        }
    }

    private var tableHeader: some View {
        HStack(spacing: 0) {
            HeaderCell(title: "Creative", active: sortKey == .title, alignment: .leading, width: nil) { tapped(.title) }
                .frame(maxWidth: .infinity, alignment: .leading)
            HeaderCell(title: "Channel", active: sortKey == .channel, alignment: .leading, width: Col.channel) { tapped(.channel) }
            HeaderCell(title: "Spend", active: sortKey == .spend, alignment: .trailing, width: Col.spend) { tapped(.spend) }
            HeaderCell(title: "Clicks", active: sortKey == .clicks, alignment: .trailing, width: Col.clicks) { tapped(.clicks) }
            HeaderCell(title: "Click rate", active: sortKey == .ctr, alignment: .trailing, width: Col.ctr) { tapped(.ctr) }
            HeaderCell(title: "Cost per sale", active: sortKey == .cpa, alignment: .trailing, width: Col.cpa) { tapped(.cpa) }
            Text("Trend")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Palette.muted)
                .frame(width: Col.trend, alignment: .trailing)
        }
        .padding(.bottom, 10)
    }

    private func tapped(_ key: SortKey) {
        withAnimation(Motion.quick) {
            if sortKey == key {
                descending.toggle()
            } else {
                sortKey = key
                descending = key != .title && key != .channel
            }
        }
    }

    private func tag(for result: ZResult) -> (String, String)? {
        guard filtered.count >= 2 else { return nil }
        if result.id == bestID { return ("Winning", "arrow.up.right") }
        if result.id == worstID { return ("Tired", "arrow.down.right") }
        return nil
    }

    // MARK: Learned

    private var learned: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHead(title: "What Figaro learned")
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(Self.insights.enumerated()), id: \.offset) { index, insight in
                    VStack(alignment: .leading, spacing: 0) {
                        if index > 0 { Rectangle().fill(Palette.hairline).frame(height: 1) }
                        InsightRow(store: store, insight: insight).padding(.vertical, 16)
                    }
                }
            }
            .zCard()
        }
    }

    private static let insights: [ZInsight] = [
        ZInsight(text: "Hands and sand beat packshots by 38%.",
                 card: Answer.Card(image: "chill", title: "Hands and sand, not packshots.", line: ""), route: .image),
        ZInsight(text: "Tuesday 9:00 is your LinkedIn slot.",
                 card: Answer.Card(image: "focus", title: "Set for Tuesday, 9:00.", line: ""), route: .calendar),
        ZInsight(text: "Glow's ad is tiring after 5 days: swap the image.",
                 card: Answer.Card(image: "glow", title: "A new image for Glow.", line: ""), route: .image),
    ]

    private func createBrief() {
        store.toast("Brief ready in Figaro")
        ZahirNav.open(.figaro)
    }

    /// Named states for Snapshot: each is rendered to a PNG for review.
    @MainActor static var snapshots: [(String, AnyView)] {
        [("results-1-week", AnyView(ResultsSurface()))]
    }
}

// MARK: - Column widths, shared by the header and every row

private enum Col {
    static let channel: CGFloat = 106
    static let spend: CGFloat = 72
    static let clicks: CGFloat = 72
    static let ctr: CGFloat = 88
    static let cpa: CGFloat = 104
    static let trend: CGFloat = 84
}

private func money(_ value: Double, cents: Bool = false) -> String {
    cents ? String(format: "$%.2f", value) : String(format: "$%.0f", value)
}

// MARK: - Summary figure

private struct PlainFigure: View {
    let label: String
    let value: String
    let meaning: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Palette.muted)
            Text(value)
                .font(.system(size: 21, weight: .semibold).monospacedDigit())
                .foregroundStyle(Palette.ink)
            Text(meaning)
                .font(.system(size: 12))
                .foregroundStyle(Palette.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.vertical, 4)
    }
}

// MARK: - Table header cell

private struct HeaderCell: View {
    let title: String
    let active: Bool
    let alignment: Alignment
    let width: CGFloat?
    let action: () -> Void
    @State private var over = false

    var body: some View {
        Button(action: action) {
            VStack(alignment: alignment == .trailing ? .trailing : .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(active ? Palette.ink : (over ? Palette.ink.opacity(0.7) : Palette.muted))
                Rectangle()
                    .fill(active ? Palette.ink : .clear)
                    .frame(height: 1.5)
            }
        }
        .buttonStyle(.plain)
        .frame(width: width, alignment: alignment)
        .onHover { hovering in withAnimation(Motion.quick) { over = hovering } }
    }
}

// MARK: - Table row

private struct CreativeRow: View {
    let result: ZResult
    let tag: (String, String)?

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            HStack(spacing: 10) {
                Shot(name: result.image)
                    .frame(width: 40, height: 40)
                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                VStack(alignment: .leading, spacing: 3) {
                    Text(result.title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Palette.ink)
                        .lineLimit(1)
                    if let tag {
                        Tag(text: tag.0, symbol: tag.1)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Tag(text: result.channel)
                .frame(width: Col.channel, alignment: .leading)

            Text(money(Double(result.spend)))
                .font(.system(size: 13).monospacedDigit())
                .foregroundStyle(Palette.ink)
                .frame(width: Col.spend, alignment: .trailing)

            Text("\(result.clicks)")
                .font(.system(size: 13).monospacedDigit())
                .foregroundStyle(Palette.ink)
                .frame(width: Col.clicks, alignment: .trailing)

            Text(String(format: "%.1f%%", result.ctr))
                .font(.system(size: 13).monospacedDigit())
                .foregroundStyle(Palette.ink)
                .frame(width: Col.ctr, alignment: .trailing)

            Text(String(format: "$%.2f", result.cpa))
                .font(.system(size: 13).monospacedDigit())
                .foregroundStyle(Palette.ink)
                .frame(width: Col.cpa, alignment: .trailing)

            ResultsSparkline(values: result.week)
                .frame(width: Col.trend - 10, height: 22)
                .frame(width: Col.trend, alignment: .trailing)
        }
    }
}

/// A plain line over a week of clicks: no axes, no labels, just the shape.
private struct ResultsSparkline: View {
    let values: [Double]

    var body: some View {
        GeometryReader { geo in
            let maxV = values.max() ?? 1
            let minV = values.min() ?? 0
            let range = max(maxV - minV, 0.0001)
            Path { path in
                for (index, value) in values.enumerated() {
                    let x = values.count > 1 ? geo.size.width * CGFloat(index) / CGFloat(values.count - 1) : 0
                    let y = geo.size.height * (1 - CGFloat((value - minV) / range))
                    if index == 0 { path.move(to: CGPoint(x: x, y: y)) }
                    else { path.addLine(to: CGPoint(x: x, y: y)) }
                }
            }
            .stroke(Palette.ink.opacity(0.7), style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
        }
    }
}

// MARK: - What Figaro learned

private struct ZInsight {
    let text: String
    let card: Answer.Card
    let route: ZahirRoute
}

private struct InsightRow: View {
    @ObservedObject var store: ZahirStore
    let insight: ZInsight

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            FigaroMark(size: 20)
            Text(insight.text)
                .font(.system(size: 14))
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: 8) {
                Chip(text: "Remember") {
                    store.remember(insight.text, from: "Results, last 7 days")
                    store.toast("Added to memory")
                }
                Chip(text: "Act on it") {
                    Studio.open(insight.card, in: insight.route)
                }
            }
        }
    }
}
