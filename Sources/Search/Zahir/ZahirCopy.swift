import SwiftUI
import AppKit

// The copy desk: headlines, captions and scripts, always checked against the
// brand's own voice before they're offered. Tone is the one dial that
// actually rewrites the six drafts — calm banks read like Palmix, the
// loudest bank reaches for the words the brand room says never to use, and
// the desk catches them with a thin red underline, live, the way Figaro
// would before anything went out.

private enum CopyFormat: String, CaseIterable {
    case headline = "Headline", caption = "Caption", script = "Script", subject = "Email subject"
}

private enum CopyLength: String, CaseIterable {
    case short = "Short", medium = "Medium", long = "Long"
}

private enum CopyLanguage: String, CaseIterable {
    case en = "EN", es = "ES", de = "DE", pt = "PT"
}

// MARK: - Voice guard

/// Finds a banned phrase in a line of copy, ignoring case and the
/// punctuation the brand room happens to store it with.
private enum VoiceGuard {
    static func key(_ phrase: String) -> String {
        phrase.trimmingCharacters(in: CharacterSet(charactersIn: ".!")).lowercased()
    }

    static func offending(in text: String, dont: [String]) -> String? {
        for phrase in dont {
            let k = key(phrase)
            guard !k.isEmpty, text.range(of: k, options: .caseInsensitive) != nil else { continue }
            return k
        }
        return nil
    }
}

/// A line of copy with any offending phrase underlined in red — the one
/// place in this desk that isn't ink, muted grey or a hairline.
private func styledLine(_ text: String, offendingKey: String?, size: CGFloat, weight: Font.Weight, color: Color) -> Text {
    guard let offendingKey, let range = text.range(of: offendingKey, options: .caseInsensitive) else {
        return Text(text).font(.system(size: size, weight: weight)).foregroundColor(color)
    }
    let before = Text(String(text[text.startIndex..<range.lowerBound]))
        .font(.system(size: size, weight: weight)).foregroundColor(color)
    let flagged = Text(String(text[range]))
        .font(.system(size: size, weight: weight)).foregroundColor(.red).underline(true, color: .red)
    let after = Text(String(text[range.upperBound...]))
        .font(.system(size: size, weight: weight)).foregroundColor(color)
    return before + flagged + after
}

// MARK: - The banks

/// Five banks, calm to loud, each with six cards' worth of copy plus a
/// second take for every card, so "Another take" never repeats what a
/// neighbouring card is already showing.
private enum CopyBank {
    static let names = ["Calm", "Warm", "Bright", "Loud", "Too loud"]

    static let banks: [[(String, String)]] = [bank0, bank1, bank2, bank3, bank4]

    private static let bank0: [(String, String)] = [
        ("Watermelon, coconut, and a minute to sit.", "Cold from the fridge, gone before you notice the clock."),
        ("The 3pm dip has a drink now.", "Watermelon and coconut. Nothing added, nothing to explain."),
        ("Slow down. It's just 3pm.", "Watermelon and coconut, the way both taste on their own."),
        ("A quiet way through the afternoon.", "No caffeine, no crash. Watermelon, coconut, a short pause."),
        ("Energy, the Palmix way: unhurried.", "Watermelon and coconut, sugar you can read on the label."),
        ("Not a boost. A breath.", "Cold watermelon and coconut water, for the slow hour."),
        ("Watermelon and coconut. That's it.", "No claims, no rush, just the 3pm can."),
        ("For the hour nobody plans for.", "Watermelon, coconut, a minute at your desk."),
        ("The afternoon, made a little easier.", "Cold, plain, watermelon and coconut water."),
        ("Your 3pm, minus the crash.", "Watermelon and coconut, sugar you can actually read."),
        ("Still just coconut water. Plus watermelon.", "Nothing hidden, nothing to decode, just cold and easy."),
        ("A short pause, bottled.", "Watermelon and coconut, for whenever 3pm finds you."),
    ]

    private static let bank1: [(String, String)] = [
        ("The 3pm dip just got a fix.", "Watermelon and coconut, with a little more lift than Chill."),
        ("Watermelon, coconut, and a small lift.", "Enough to notice, not enough to crash from."),
        ("A break, not a boost.", "Watermelon and coconut, doing exactly what it says."),
        ("Palmix Energy: watermelon meets the slow kind.", "Still coconut water first, watermelon and a little more."),
        ("A cold reset for the afternoon.", "Watermelon and coconut, poured straight from the fridge."),
        ("Watermelon and coconut, right on time.", "For the hour that always needs one."),
        ("Lift, without losing the slow part.", "Watermelon and coconut, the Palmix way, a little brighter."),
        ("Your afternoon, gently nudged awake.", "Watermelon and coconut, nothing sharper than that."),
        ("Watermelon-coconut, built for the dip.", "Sugar you can read on the label, still."),
        ("A little brighter by 3pm.", "Watermelon and coconut, the same honest can."),
        ("The pause that still moves you.", "Watermelon and coconut, for the second half of the day."),
        ("Cold, bright, and quietly effective.", "Watermelon and coconut, doing more than it lets on."),
    ]

    private static let bank2: [(String, String)] = [
        ("Beat the 3pm dip, calmly.", "Watermelon and coconut, made for the hour everyone feels."),
        ("Watermelon, coconut, and real momentum.", "A bit more than Chill, still nothing you can't read."),
        ("The afternoon just found its flavor.", "Watermelon and coconut, built for the second half of the day."),
        ("Energy that still tastes like a break.", "Watermelon and coconut, the Palmix way, just brighter."),
        ("Watermelon-coconut for the 3pm comeback.", "For the hour that needs a little more."),
        ("Wake the afternoon up, gently.", "Watermelon and coconut, straight from the fridge."),
        ("A brighter dip, same honest can.", "Watermelon and coconut, sugar you can still read."),
        ("Your 3pm, now with watermelon.", "A little lift, none of the noise."),
        ("The good kind of afternoon jolt.", "Watermelon and coconut, nothing added to explain."),
        ("Coconut water with a watermelon kick.", "Built for the hour that always needs one."),
        ("Steady energy, straight from the can.", "Watermelon and coconut, the same slow honesty."),
        ("3pm, but make it watermelon.", "Watermelon and coconut, doing the afternoon's work."),
    ]

    private static let bank3: [(String, String)] = [
        ("Beat the 3pm slump before it even starts today.", "Watermelon and coconut, made for the hour that wrecks your focus."),
        ("Watermelon, coconut, and the energy you actually want.", "A bigger lift than Chill, a calmer one than coffee."),
        ("The pick-me-up that never feels like one.", "Watermelon and coconut, working quietly in the background."),
        ("A watermelon boost for the 3pm crowd.", "Built for the people who feel the dip hardest."),
        ("Finally, an energy drink that still tastes calm.", "Watermelon and coconut, doing more than either lets on."),
        ("Your 3pm pick-me-up, watermelon and coconut style.", "No crash after, just the rest of your afternoon."),
        ("The 3pm boost that still feels like Palmix.", "Watermelon and coconut, a little louder than Chill."),
        ("Watermelon energy, dialed up just a little.", "For the days that need more than a slow sip."),
        ("More lift for the same honest can.", "Watermelon and coconut, doing the heavier lifting now."),
        ("The afternoon boost you didn't know you needed.", "Watermelon and coconut, working harder than it looks."),
        ("A brighter, faster way through the dip.", "Watermelon and coconut, built for the busy hour."),
        ("3pm energy, turned up one notch.", "Watermelon and coconut, with a little more reach."),
    ]

    private static let bank4: [(String, String)] = [
        ("Crush your goals, one can at a time!", "Watermelon and coconut, unlocked for your biggest day yet!"),
        ("Meet your new superfood obsession!", "Coconut and watermelon, seamless energy from can to can!"),
        ("The hydration revolution starts at 3pm!", "Watermelon and coconut, elevate every single afternoon!"),
        ("Crush your goals. Every. Single. Can.", "Watermelon-coconut, built to fuel the whole grind, no excuses!"),
        ("This can is basically a superfood!", "Watermelon and coconut, a total lifestyle upgrade!"),
        ("Join the hydration revolution, watermelon style!", "Crush the 3pm slump before it crushes you!"),
        ("Crush your goals before lunch even ends!", "Watermelon and coconut, unlocked, unleashed, unstoppable!"),
        ("Superfood energy, watermelon flavor!", "A full hydration revolution, one can at a time!"),
        ("The hydration revolution is finally bottled!", "Watermelon and coconut, made to help you crush your goals!"),
        ("Crush your goals, then crush another can!", "Watermelon-powered, seriously superfood-level energy!"),
        ("This superfood doesn't do subtle!", "Watermelon and coconut, fueling your personal hydration revolution!"),
        ("Hydration revolution: now in watermelon!", "Crush your goals, sip by sip, can by can!"),
    ]
}

/// One card's draft: which bank it came from, which of the bank's two takes
/// it's showing, and whether it's been shortened or kept. Headline and body
/// are derived, never stored, so "Shorter" and "Another take" can't drift
/// out of sync with the rules that check them.
private struct Variant: Identifiable {
    let id = UUID()
    let bank: Int
    let slot: Int
    var altOn = false
    var shortOn = false
    var kept = false

    private var pair: (String, String) {
        let pairs = CopyBank.banks[bank]
        return pairs[altOn ? slot + 6 : slot]
    }

    var headline: String { shortOn ? Self.shorten(pair.0) : pair.0 }
    var body: String { shortOn ? Self.shortenBody(pair.1) : pair.1 }

    static func deal(bank: Int) -> [Variant] {
        (0..<6).map { Variant(bank: bank, slot: $0) }
    }

    private static func shorten(_ text: String) -> String {
        let words = text.split(separator: " ")
        guard words.count > 4 else { return text }
        return words.prefix(4).joined(separator: " ")
    }

    private static func shortenBody(_ text: String) -> String {
        if let dot = text.firstIndex(of: ".") { return String(text[..<dot]) + "." }
        if let comma = text.firstIndex(of: ",") { return String(text[..<comma]) + "." }
        return text
    }
}

// MARK: - Controls

/// A product's picture and name, opening a menu of the rest. Snapshot
/// renders with ImageRenderer, which draws a native Menu as an oversized
/// placeholder rather than its SwiftUI label — so under Snapshot this shows
/// the same chip as a plain view instead, with no dropdown behind it.
private struct ProductMenu: View {
    let brand: ZBrand
    @Binding var productID: String
    @State private var over = false

    private var product: ZProduct? { brand.products.first { $0.id == productID } }

    var body: some View {
        Group {
            if Snapshot.running {
                chip
            } else {
                Menu {
                    ForEach(brand.products) { p in
                        Button {
                            productID = p.id
                        } label: {
                            Label {
                                Text(p.name)
                            } icon: {
                                Image(nsImage: Shots.image(p.image) ?? NSImage())
                            }
                        }
                    }
                } label: {
                    chip
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }
        }
        .onHover { hovering in withAnimation(Motion.quick) { over = hovering } }
    }

    private var chip: some View {
        HStack(spacing: 8) {
            ZStack {
                if let product { Shot(name: product.image) } else { Palette.wash }
            }
            .frame(width: 22, height: 22)
            .clipShape(Circle())
            Text(product?.name ?? "Pick a product")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Palette.ink)
            Image(systemName: "chevron.down")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(Palette.muted)
        }
        .padding(.horizontal, 10)
        .frame(height: 30)
        .background(Capsule().fill(over ? Palette.hover : Palette.wash))
    }
}

/// Calm to loud: a hairline track, an ink knob, five detents. Click
/// anywhere to jump, or drag — both land on the nearest detent.
private struct ToneSlider: View {
    @Binding var tone: Int
    private let steps = 5
    private let inset: CGFloat = 9
    @State private var dragging = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Calm").font(.system(size: 12)).foregroundStyle(Palette.muted)
                Spacer()
                Text("Loud").font(.system(size: 12)).foregroundStyle(Palette.muted)
            }
            GeometryReader { geo in
                let width = max(geo.size.width, 1)
                ZStack(alignment: .leading) {
                    Capsule().fill(Palette.hairline).frame(width: width, height: 1)
                    ForEach(0..<steps, id: \.self) { step in
                        Circle()
                            .fill(step <= tone ? Palette.ink.opacity(0.35) : Palette.hairline)
                            .frame(width: 5, height: 5)
                            .offset(x: x(for: step, width: width) - 2.5)
                    }
                    Circle()
                        .fill(Palette.ink)
                        .frame(width: 18, height: 18)
                        .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
                        .scaleEffect(dragging ? 1.15 : 1)
                        .offset(x: x(for: tone, width: width) - 9)
                }
                .frame(width: width, height: 18)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            dragging = true
                            let step = nearest(x: value.location.x, width: width)
                            if step != tone { withAnimation(Motion.quick) { tone = step } }
                        }
                        .onEnded { _ in dragging = false }
                )
            }
            .frame(height: 18)
        }
    }

    private func x(for step: Int, width: CGFloat) -> CGFloat {
        let usable = max(width - inset * 2, 1)
        return inset + usable * CGFloat(step) / CGFloat(steps - 1)
    }

    private func nearest(x: CGFloat, width: CGFloat) -> Int {
        let usable = max(width - inset * 2, 1)
        let clamped = min(max(x, inset), width - inset)
        let ratio = (clamped - inset) / usable
        return min(steps - 1, max(0, Int((ratio * CGFloat(steps - 1)).rounded())))
    }
}

// MARK: - A variant card

private struct VariantCardView: View {
    let index: Int
    let variant: Variant
    let brand: ZBrand
    let onKeep: () -> Void
    let onShorter: () -> Void
    let onAnother: () -> Void
    @State private var over = false

    private var offendingKey: String? {
        VoiceGuard.offending(in: variant.headline + " " + variant.body, dont: brand.voiceDont)
    }
    private var wordRule: ZRule? { brand.rules.first { $0.id == "words" } }
    private var wordsOK: Bool {
        guard let wordRule, wordRule.on else { return true }
        return variant.headline.split(separator: " ").count <= 7
    }
    private var voiceOK: Bool { offendingKey == nil }
    private var fits: Bool { wordsOK && voiceOK }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            badge
            VStack(alignment: .leading, spacing: 6) {
                styledLine(variant.headline, offendingKey: offendingKey, size: 20, weight: .semibold, color: Palette.ink)
                    .contentTransition(.opacity)
                    .fixedSize(horizontal: false, vertical: true)
                styledLine(variant.body, offendingKey: offendingKey, size: 14, weight: .regular, color: Palette.muted)
                    .contentTransition(.opacity)
                    .fixedSize(horizontal: false, vertical: true)
                Flow(spacing: 6, line: 6) {
                    Tag(text: fits ? "Fits the voice" : "Too loud for Palmix",
                        symbol: fits ? "checkmark" : "exclamationmark", strong: fits)
                    if let wordRule, wordRule.on {
                        Tag(text: wordRule.text, symbol: wordsOK ? "checkmark" : "xmark")
                    }
                    Tag(text: "No banned phrases", symbol: voiceOK ? "checkmark" : "xmark")
                }
                .padding(.top, 2)
                if over {
                    HStack(spacing: 6) {
                        Chip(text: variant.kept ? "Kept" : "Keep", action: onKeep)
                        Chip(text: variant.shortOn ? "Longer" : "Shorter", action: onShorter)
                        Chip(text: "Another take", action: onAnother)
                        Chip(text: "Copy", action: copy)
                    }
                    .transition(.opacity)
                }
            }
            Spacer(minLength: 0)
        }
        .zCard(radius: 16, padding: 14, shadow: false)
        .onHover { hovering in withAnimation(Motion.quick) { over = hovering } }
        .animation(Motion.quick, value: over)
    }

    private var badge: some View {
        Group {
            if variant.kept {
                ZStack {
                    Circle().fill(Palette.ink)
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Palette.ground)
                }
                .frame(width: 26, height: 26)
            } else {
                NumberBadge(number: index + 1)
            }
        }
    }

    private func copy() {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(variant.headline + "\n" + variant.body, forType: .string)
        ZahirStore.shared.toast("Copied")
    }
}

// MARK: - Right panel

private struct VoicePanel: View {
    let brand: ZBrand

    private static let caught: [(before: String, after: String)] = [
        ("Unlock your best afternoon yet!", "Your afternoon, made a little easier."),
        ("The hydration revolution starts now!", "Coconut water and nothing else."),
        ("Crush the 3pm slump with pure energy!", "Watermelon and coconut, for the 3pm dip."),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 12) {
                Text("\(brand.name) sounds like")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                Flow(spacing: 8, line: 8) {
                    ForEach(brand.voice, id: \.self) { word in
                        Tag(text: word, strong: true)
                    }
                }
            }
            Rectangle().fill(Palette.hairline).frame(height: 1)
            VStack(alignment: .leading, spacing: 16) {
                VoiceLines(label: "Say", lines: brand.voiceDo, muted: false)
                VoiceLines(label: "Don't say", lines: brand.voiceDont, muted: true)
            }
            Rectangle().fill(Palette.hairline).frame(height: 1)
            VStack(alignment: .leading, spacing: 12) {
                Text("Caught this week")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                ForEach(Self.caught, id: \.before) { pair in
                    CaughtRow(before: pair.before, after: pair.after)
                }
            }
        }
        .zCard(radius: 20)
    }
}

private struct VoiceLines: View {
    let label: String
    let lines: [String]
    let muted: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(muted ? Palette.muted : Palette.ink)
            ForEach(lines, id: \.self) { line in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: muted ? "xmark" : "checkmark")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Palette.muted)
                        .padding(.top, 3)
                    Text(line)
                        .strikethrough(muted, color: Palette.muted)
                        .font(.system(size: 13))
                        .foregroundStyle(muted ? Palette.muted : Palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

private struct CaughtRow: View {
    let before: String
    let after: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(before)
                .font(.system(size: 12))
                .foregroundStyle(Palette.muted)
                .strikethrough(true, color: Palette.muted)
                .fixedSize(horizontal: false, vertical: true)
            HStack(alignment: .top, spacing: 6) {
                Image(systemName: "arrow.turn.down.right")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Palette.muted)
                Text(after)
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.bottom, 4)
    }
}

// MARK: - The desk

struct CopyDesk: View {
    @ObservedObject var store = ZahirStore.shared

    @State private var productID = "energy"
    @State private var channel = "Instagram"
    @State private var audience = "The 3pm breakers"
    @State private var format: CopyFormat = .headline
    @State private var tone: Int
    @State private var length: CopyLength = .medium
    @State private var language: CopyLanguage = .en
    @State private var cards: [Variant]
    @State private var writing = false
    @State private var writingTask: Task<Void, Never>?

    /// `tone` pins the slider for Snapshot, without touching the shared store.
    init(tone: Int? = nil) {
        let t = tone ?? 2
        _tone = State(initialValue: t)
        _cards = State(initialValue: Variant.deal(bank: t))
    }

    /// Always Palmix: the banks above are written for it, so the desk reads
    /// its rules and voice from there rather than whatever brand is active
    /// elsewhere in the app.
    private var brand: ZBrand { store.brands.first { $0.id == "palmix" } ?? store.brand }
    private var product: ZProduct? { brand.products.first { $0.id == productID } }

    var body: some View {
        SurfacePage(title: "Copy desk", line: "Headlines, captions and scripts, in \(brand.name)'s voice.") {
            PrimaryButton(title: "Write 6 more", action: writeMore)
        } content: {
            VStack(alignment: .leading, spacing: 18) {
                briefControlsCard
                HStack(alignment: .top, spacing: 24) {
                    variantsColumn
                        .frame(maxWidth: .infinity, alignment: .leading)
                    VoicePanel(brand: brand)
                        .frame(width: 280)
                }
            }
        }
        .onChange(of: tone) { _, newValue in
            withAnimation(Motion.settle) { cards = Variant.deal(bank: newValue) }
        }
        .onDisappear { writingTask?.cancel() }
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text).font(.system(size: 13, weight: .medium)).foregroundStyle(Palette.muted)
    }

    // MARK: Brief + controls

    /// One card, two rows: what's being written (row 1), and how it sounds
    /// (row 2) — kept to two rows and tight padding so the variants below
    /// still get most of the page.
    private var briefControlsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHead(title: "Brief")
            HStack(alignment: .top, spacing: 24) {
                VStack(alignment: .leading, spacing: 5) {
                    fieldLabel("Product")
                    ProductMenu(brand: brand, productID: $productID)
                }
                VStack(alignment: .leading, spacing: 5) {
                    fieldLabel("Channel")
                    Flow(spacing: 6, line: 6) {
                        ForEach(brand.channels, id: \.self) { c in
                            Choice(text: c, on: c == channel) { channel = c }
                        }
                    }
                }
                VStack(alignment: .leading, spacing: 5) {
                    fieldLabel("Audience")
                    Flow(spacing: 6, line: 6) {
                        ForEach(brand.audiences) { a in
                            Choice(text: a.name, on: a.name == audience) { audience = a.name }
                        }
                    }
                }
                VStack(alignment: .leading, spacing: 5) {
                    fieldLabel("Format")
                    Flow(spacing: 6, line: 6) {
                        ForEach(CopyFormat.allCases, id: \.self) { f in
                            Choice(text: f.rawValue, on: f == format) { format = f }
                        }
                    }
                }
            }
            Rectangle().fill(Palette.hairline).frame(height: 1)
            HStack(alignment: .top, spacing: 24) {
                VStack(alignment: .leading, spacing: 6) {
                    fieldLabel("Tone")
                    ToneSlider(tone: $tone)
                }
                .frame(width: 260)
                VStack(alignment: .leading, spacing: 5) {
                    fieldLabel("Length")
                    Flow(spacing: 6, line: 6) {
                        ForEach(CopyLength.allCases, id: \.self) { l in
                            Choice(text: l.rawValue, on: l == length) { length = l }
                        }
                    }
                }
                VStack(alignment: .leading, spacing: 5) {
                    fieldLabel("Language")
                    Flow(spacing: 6, line: 6) {
                        ForEach(CopyLanguage.allCases, id: \.self) { l in
                            Choice(text: l.rawValue, on: l == language) { language = l }
                        }
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .zCard(padding: 16)
    }

    // MARK: Variants

    private static let variantColumns = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]

    private var variantsColumn: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHead(title: "Variants", line: "\(CopyBank.names[tone]) · \(format.rawValue)")
            LazyVGrid(columns: Self.variantColumns, spacing: 14) {
                ForEach(Array(cards.enumerated()), id: \.element.id) { index, variant in
                    Dealt(index: index, crooked: false) {
                        VariantCardView(
                            index: index,
                            variant: variant,
                            brand: brand,
                            onKeep: { keep(index) },
                            onShorter: { toggleShort(index) },
                            onAnother: { anotherTake(index) }
                        )
                    }
                }
            }
            .opacity(writing ? 0.35 : 1)
        }
    }

    // MARK: Actions

    private func keep(_ i: Int) {
        guard cards.indices.contains(i), !cards[i].kept else { return }
        withAnimation(Motion.quick) { cards[i].kept = true }
        let variant = cards[i]
        store.keep(ZAsset(.copy, variant.headline, image: product?.image, product: product?.name, channel: channel, made: "Today"))
    }

    private func toggleShort(_ i: Int) {
        guard cards.indices.contains(i) else { return }
        withAnimation(Motion.quick) { cards[i].shortOn.toggle() }
    }

    private func anotherTake(_ i: Int) {
        guard cards.indices.contains(i) else { return }
        withAnimation(Motion.quick) { cards[i].altOn.toggle() }
    }

    private func writeMore() {
        writingTask?.cancel()
        withAnimation(Motion.quick) { writing = true }
        writingTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 380_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(Motion.settle) {
                cards = Variant.deal(bank: tone)
                writing = false
            }
        }
    }

    /// Named states for Snapshot: each is rendered to a PNG for review.
    @MainActor static var snapshots: [(String, AnyView)] {
        [
            ("copy-1-calm", AnyView(CopyDesk(tone: 0).frame(width: 1180, height: 740))),
            ("copy-2-loud", AnyView(CopyDesk(tone: 4).frame(width: 1180, height: 740))),
        ]
    }
}
