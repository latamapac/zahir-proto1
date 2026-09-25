import SwiftUI

// The research board: what the market is doing, read every morning so the
// next brief starts from something true. A row of competitors, one opened
// wide with its ads and Figaro's notes, the gap it leaves, what's trending,
// and whatever you've clipped from a page with ⇧⌘E.

struct ResearchBoard: View {
    @ObservedObject var store = ZahirStore.shared

    @State private var selectedID: String
    @State private var reading = false

    /// `selectedID` pins the open competitor for Snapshot.
    init(selectedID: String? = nil) {
        _selectedID = State(initialValue: selectedID ?? ZahirStore.seedCompetitors.first?.id ?? "")
    }

    private var selected: ZCompetitor? {
        store.competitors.first { $0.id == selectedID } ?? store.competitors.first
    }

    var body: some View {
        SurfacePage(title: "Research", line: "What your market is doing, read by Figaro every morning.") {
            Chip(text: "Watch a competitor") {
                store.toast("Figaro will start watching a new competitor once you add one.")
            }
            PrimaryButton(title: "Read the market now", action: readMarket)
        } content: {
            VStack(alignment: .leading, spacing: 36) {
                VStack(alignment: .leading, spacing: 24) {
                    competitorsRow
                    if let selected {
                        CompetitorBoard(store: store, competitor: selected)
                    }
                }
                .overlay { if reading { ReadingShimmer().allowsHitTesting(false) } }
                .clipped()

                TrendsSection()
                ClipsSection(store: store)
            }
        }
    }

    private var competitorsRow: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHead(title: "Competitors", line: "Figaro checks their sites and live ads every morning.")
            HStack(alignment: .top, spacing: 16) {
                ForEach(store.competitors) { competitor in
                    CompetitorCard(competitor: competitor, selected: competitor.id == selectedID) {
                        withAnimation(Motion.settle) { selectedID = competitor.id }
                    }
                }
            }
        }
    }

    private func readMarket() {
        guard !reading else { return }
        withAnimation(Motion.quick) { reading = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(Motion.settle) { reading = false }
            store.toast("3 new things since yesterday")
        }
    }

    /// Named states for Snapshot: each is rendered to a PNG for review.
    @MainActor static var snapshots: [(String, AnyView)] {
        [("research-1-board", AnyView(ResearchBoard(selectedID: "vitacoco")))]
    }
}

// MARK: - Competitor card

private struct CompetitorCard: View {
    let competitor: ZCompetitor
    let selected: Bool
    let action: () -> Void
    @State private var over = false

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 14) {
                Shot(name: competitor.image)
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                VStack(alignment: .leading, spacing: 4) {
                    Text(competitor.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Palette.ink)
                    Text(competitor.site)
                        .font(.system(size: 12))
                        .foregroundStyle(Palette.muted)
                    Text("Owns: \(competitor.owns.firstLower)")
                        .font(.system(size: 12))
                        .foregroundStyle(Palette.muted)
                        .padding(.top, 2)
                    HStack(spacing: 4) {
                        Text("\(competitor.ads)")
                            .font(.system(size: 12, weight: .semibold).monospacedDigit())
                            .foregroundStyle(Palette.ink)
                        Text("live ads")
                            .font(.system(size: 12))
                            .foregroundStyle(Palette.muted)
                    }
                    .padding(.top, 4)
                }
                Spacer(minLength: 0)
            }
            .padding(16)
            .frame(width: 280, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(selected ? Palette.wash : Palette.ground))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(selected ? Palette.ink : Palette.hairline, lineWidth: selected ? 1.5 : 1))
            .shadow(color: .black.opacity(over && !selected ? 0.08 : 0), radius: 16, y: 6)
        }
        .buttonStyle(.plain)
        .onHover { hovering in withAnimation(Motion.quick) { over = hovering } }
    }
}

// MARK: - Competitor board: their ads, Figaro's notes, the gap

private struct CompetitorBoard: View {
    @ObservedObject var store: ZahirStore
    let competitor: ZCompetitor

    private static let demoImages = ["chill", "energy", "focus", "fun", "glow", "recover"]
    private static let captions = ["Instagram, this week", "Meta Ads, running now", "Their site", "TikTok, recent"]

    private var clippedAds: [(image: String, caption: String)] {
        let seed = competitor.id.utf8.reduce(0) { $0 + Int($1) }
        let count = competitor.notes.count >= 3 ? 4 : 3
        return (0..<count).map { i in
            (Self.demoImages[(seed + i) % Self.demoImages.count], Self.captions[i % Self.captions.count])
        }
    }

    private var gap: String {
        switch competitor.id {
        case "vitacoco": return "Nobody talks about the afternoon. Palmix can own calm."
        case "harmless": return "Nobody talks about taste, only where it's from. Palmix can own taste."
        case "zola": return "Nobody talks about adults. Palmix can own the office too."
        default: return "Figaro is still reading. The gap isn't clear yet."
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            SectionHead(title: "\(competitor.name)'s ads", line: "\(competitor.ads) running now")
            HStack(alignment: .top, spacing: 18) {
                ForEach(Array(clippedAds.enumerated()), id: \.offset) { index, ad in
                    Dealt(index: index) {
                        VStack(spacing: 6) {
                            Shot(name: ad.image)
                                .frame(width: 118, height: 148)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            Text(ad.caption)
                                .font(.system(size: 11))
                                .foregroundStyle(Palette.muted)
                        }
                    }
                }
            }
            .padding(.top, 6)

            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(competitor.notes.enumerated()), id: \.offset) { index, note in
                    VStack(alignment: .leading, spacing: 0) {
                        if index > 0 { Rectangle().fill(Palette.hairline).frame(height: 1) }
                        HStack(alignment: .top, spacing: 12) {
                            FigaroMark(size: 18)
                            Text(note)
                                .font(.system(size: 14))
                                .foregroundStyle(Palette.ink)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.vertical, 12)
                    }
                }
            }
            .zCard()

            GapCallout(store: store, competitorName: competitor.name, text: gap)
        }
    }
}

private struct GapCallout: View {
    @ObservedObject var store: ZahirStore
    let competitorName: String
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "lightbulb")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                Text("The gap")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Palette.ink)
            }
            Text(text)
                .font(.system(size: 18, weight: .medium))
                .tracking(-0.2)
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 8) {
                Chip(text: "Make ads for this") {
                    Studio.open(Answer.Card(image: "energy", title: "Your 3pm, without the crash.", line: ""), in: .image)
                }
                Chip(text: "Remember this") {
                    store.remember(text, from: "Research, \(competitorName)")
                    store.toast("Added to memory")
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Palette.ground))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Palette.ink, lineWidth: 1.5))
    }
}

// MARK: - Trends

private struct ZTrend {
    let term: String
    let up: Bool
    let percent: Int
    let meaning: String
    let weeks: [Double]
}

private struct TrendsSection: View {
    private let trends: [ZTrend] = [
        ZTrend(term: "coconut water afternoon", up: true, percent: 31,
               meaning: "People are searching for a 3pm drink, not just a post-workout one.",
               weeks: [10, 12, 11, 14, 16, 15, 18, 21]),
        ZTrend(term: "sugar free electrolyte", up: true, percent: 14,
               meaning: "Chill is the closest fit in the lineup. Nobody's said so yet.",
               weeks: [30, 31, 29, 33, 34, 33, 36, 38]),
        ZTrend(term: "hydration drink", up: false, percent: 9,
               meaning: "The category term is fading. Say what it tastes like instead.",
               weeks: [42, 40, 39, 37, 36, 35, 33, 32]),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHead(title: "Trends", line: "Eight weeks of search, read alongside your category.")
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(trends.enumerated()), id: \.offset) { index, trend in
                    VStack(alignment: .leading, spacing: 0) {
                        if index > 0 { Rectangle().fill(Palette.hairline).frame(height: 1) }
                        TrendRow(trend: trend).padding(.vertical, 14)
                    }
                }
            }
            .zCard()
        }
    }
}

private struct TrendRow: View {
    let trend: ZTrend

    var body: some View {
        HStack(alignment: .center, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text("\u{201c}\(trend.term)\u{201d}")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Palette.ink)
                    Image(systemName: trend.up ? "arrow.up.right" : "arrow.down.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Palette.muted)
                    Text("\(trend.percent)%")
                        .font(.system(size: 12, weight: .semibold).monospacedDigit())
                        .foregroundStyle(Palette.muted)
                }
                Text(trend.meaning)
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 12)
            ResearchSparkline(values: trend.weeks)
                .frame(width: 120, height: 32)
        }
    }
}

/// A plain line over a handful of values: no axes, no labels, just the shape.
private struct ResearchSparkline: View {
    let values: [Double]
    var color: Color = Palette.ink

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
            .stroke(color.opacity(0.75), style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
        }
    }
}

// MARK: - Your clips

private struct ClipsSection: View {
    @ObservedObject var store: ZahirStore

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHead(title: "Your clips", line: "Point at anything on a website with ⇧⌘E.")
            if let reference = store.reference {
                HStack(spacing: 14) {
                    Group {
                        if let image = reference.image {
                            Image(nsImage: image).resizable().aspectRatio(contentMode: .fill)
                        } else {
                            Palette.wash
                        }
                    }
                    .frame(width: 72, height: 72)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    VStack(alignment: .leading, spacing: 4) {
                        Text(reference.source)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Palette.ink)
                        Text(reference.note)
                            .font(.system(size: 12))
                            .foregroundStyle(Palette.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }
                .zCard(radius: 16, padding: 14)
            } else {
                EmptyState(symbol: "cursorarrow.rays", title: "Nothing clipped yet",
                           line: "Whatever you point at gets pulled in here, ready to use.")
                    .zCard()
            }
        }
    }
}

// MARK: - Reading shimmer

/// A soft band that sweeps once across the cards while Figaro re-reads them.
private struct ReadingShimmer: View {
    @State private var move = false

    var body: some View {
        GeometryReader { geo in
            LinearGradient(colors: [.clear, Palette.ground.opacity(0.7), .clear], startPoint: .leading, endPoint: .trailing)
                .frame(width: geo.size.width * 0.5)
                .offset(x: move ? geo.size.width : -geo.size.width * 0.5)
                .onAppear {
                    guard !Snapshot.running else { return }
                    withAnimation(.linear(duration: 0.75).repeatCount(2, autoreverses: false)) { move = true }
                }
        }
    }
}

private extension String {
    var firstLower: String { isEmpty ? self : prefix(1).lowercased() + dropFirst() }
}
