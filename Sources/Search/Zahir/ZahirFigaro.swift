import SwiftUI
import AppKit

// Zahir: what Paradox adds to the browser. Figaro, the marketer you hired, sits
// over every page as one small pill. Ask, and the tools it reaches for (words,
// pictures, video, layouts, research, publishing) stay out of sight until the
// answer comes back as things you can use: cards, not paragraphs.
//
// Prototype: nothing here calls a model. The answers are written out below so
// the surfaces can be judged before Penrose is wired in.

/// Figaro's state, one per app: a pill, a question being typed, work in
/// progress, or an answer on the table.
@MainActor
final class Figaro: ObservableObject {
    static let shared = Figaro()

    enum Stage: Equatable { case resting, asking, working, answered }

    @Published private(set) var stage: Stage = .resting
    @Published var draft = ""
    /// What was open when Figaro was asked. Intents and answers are about it.
    @Published private(set) var place = Place.home
    @Published private(set) var ask = ""
    @Published private(set) var steps: [Step] = []
    @Published private(set) var done = 0
    @Published private(set) var answer: Answer?
    /// Something dropped on Figaro to work from: its label, and the picture
    /// goes to the store's reference.
    @Published var attachment: String?

    private var run: Task<Void, Never>?

    var showing: Bool { stage != .resting }

    /// ⌘J, or a click on the pill.
    func open(on tab: Tab?) {
        place = Place(tab)
        draft = ""
        withAnimation(Motion.settle) { stage = .asking }
    }

    func toggle(on tab: Tab?) {
        showing ? close() : open(on: tab)
    }

    func close() {
        run?.cancel()
        attachment = nil
        withAnimation(Motion.settle) {
            stage = .resting
            answer = nil
        }
        draft = ""
    }

    /// Text the address field could not take. It was a request, not a place.
    func take(_ text: String, on tab: Tab?) {
        place = Place(tab)
        start(text, kind: Kind.guess(from: text))
    }

    func submit() {
        let text = draft.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        if let tool = Tool.picked(by: text) {
            let rest = text.dropFirst(tool.command.count).trimmingCharacters(in: .whitespaces)
            start(rest.isEmpty ? tool.fallback : rest, kind: tool.kind)
        } else {
            start(text, kind: Kind.guess(from: text))
        }
    }

    func pick(_ intent: Intent) { start(intent.title, kind: intent.kind) }

    /// Straight to a finished answer, for the work Figaro did while you were
    /// away.
    func show(_ kind: Kind) {
        place = .home
        ask = Kind.homeAsk[kind] ?? ""
        steps = Step.plan(kind)
        done = steps.count
        answer = Answer.make(kind, ask: ask, place: place)
        withAnimation(Motion.settle) { stage = .answered }
    }

    /// Set the stage directly, for Snapshot.
    func stage(_ stage: Stage, kind: Kind, draft: String = "", place: Place = .home, done: Int? = nil) {
        self.place = place
        self.draft = draft
        ask = Kind.homeAsk[kind] ?? ""
        steps = Step.plan(kind)
        self.done = done ?? steps.count
        answer = stage == .answered ? Answer.make(kind, ask: ask, place: place) : nil
        self.stage = stage
    }

    private func start(_ text: String, kind: Kind) {
        run?.cancel()
        ask = text
        steps = Step.plan(kind)
        done = 0
        answer = nil
        draft = ""
        withAnimation(Motion.settle) { stage = .working }
        let place = place
        run = Task { @MainActor [weak self] in
            for _ in 0..<(self?.steps.count ?? 0) {
                try? await Task.sleep(nanoseconds: 620_000_000)
                guard let self, !Task.isCancelled else { return }
                withAnimation(Motion.quick) { self.done += 1 }
            }
            try? await Task.sleep(nanoseconds: 240_000_000)
            guard let self, !Task.isCancelled else { return }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.78)) {
                self.answer = Answer.make(kind, ask: text, place: place)
                self.stage = .answered
            }
        }
    }
}

// MARK: - What Figaro knows about

/// The page Figaro is looking at, or Zahir's own home.
struct Place: Equatable {
    var host: String?
    var title: String

    static let home = Place(host: nil, title: "Palmix")

    init(host: String?, title: String) {
        self.host = host
        self.title = title
    }

    @MainActor
    init(_ tab: Tab?) {
        guard let tab, let url = tab.address, ZahirRoute(url) == nil else { self = .home; return }
        host = url.host()?.replacingOccurrences(of: "www.", with: "")
        title = tab.title.isEmpty ? (host ?? "this page") : tab.title
    }

    var label: String { host.map { "on \($0)" } ?? "in Palmix" }
    /// A short name for the page, for sentences.
    var name: String {
        guard let host else { return "Palmix" }
        let first = host.split(separator: ".").first.map(String.init) ?? host
        return first.prefix(1).uppercased() + first.dropFirst()
    }

    var intents: [Intent] {
        if host == nil {
            return [
                Intent(title: "Three ads for Palmix Energy", kind: .concepts),
                Intent(title: "What is Vita Coco doing?", kind: .read),
                Intent(title: "A TikTok for the Glow launch", kind: .storyboard),
                Intent(title: "Next week's LinkedIn post", kind: .post),
            ]
        }
        return [
            Intent(title: "What is \(name) really selling?", kind: .read),
            Intent(title: "Three ads that beat this", kind: .concepts),
            Intent(title: "A 15-second video in this style", kind: .storyboard),
            Intent(title: "Turn this into a post", kind: .post),
        ]
    }
}

struct Intent: Hashable {
    let title: String
    let kind: Kind
}

/// The four shapes an answer comes back in.
enum Kind: Hashable {
    case concepts, read, storyboard, post

    static func guess(from text: String) -> Kind {
        let t = text.lowercased()
        if ["video", "tiktok", "reel", "short", "ugc", "15s", "clip"].contains(where: t.contains) { return .storyboard }
        if ["post", "linkedin", "caption", "instagram", "tweet", "schedule"].contains(where: t.contains) { return .post }
        if ["what", "why", "who", "competitor", "position", "research", "selling", "doing"].contains(where: t.contains) { return .read }
        return .concepts
    }

    static let homeAsk: [Kind: String] = [
        .concepts: "Three ads for Palmix Energy",
        .read: "What is Vita Coco doing?",
        .post: "Next week's LinkedIn post",
        .storyboard: "A TikTok for the Glow launch",
    ]
}

/// The toolkit, hidden until a slash asks for it.
enum Tool: CaseIterable {
    case write, image, video, layout, research, publish

    var command: String { "/" + name.lowercased() }
    var name: String {
        switch self {
        case .write: "Write"
        case .image: "Image"
        case .video: "Video"
        case .layout: "Layout"
        case .research: "Research"
        case .publish: "Publish"
        }
    }
    var symbol: String {
        switch self {
        case .write: "text.alignleft"
        case .image: "photo"
        case .video: "film"
        case .layout: "rectangle.3.group"
        case .research: "magnifyingglass"
        case .publish: "paperplane"
        }
    }
    var blurb: String {
        switch self {
        case .write: "Headlines, captions, scripts, emails"
        case .image: "Stills in your brand's light"
        case .video: "Shorts, UGC, product loops"
        case .layout: "One ad, every size"
        case .research: "Competitors, trends, audiences"
        case .publish: "Schedule to your channels"
        }
    }
    var kind: Kind {
        switch self {
        case .write, .publish: .post
        case .image, .layout: .concepts
        case .video: .storyboard
        case .research: .read
        }
    }
    var fallback: String {
        switch self {
        case .write: "Write next week's post"
        case .image: "Three ads for Palmix Energy"
        case .video: "A TikTok for the Glow launch"
        case .layout: "Size the Energy ad for every channel"
        case .research: "What is Vita Coco doing?"
        case .publish: "Schedule next week's post"
        }
    }

    static func picked(by text: String) -> Tool? {
        let head = text.lowercased().split(separator: " ").first.map(String.init) ?? ""
        return allCases.first { $0.command == head }
    }

    /// Tools whose command starts with what has been typed after the slash.
    static func matching(_ draft: String) -> [Tool] {
        let typed = draft.lowercased().split(separator: " ").first.map(String.init) ?? "/"
        return allCases.filter { $0.command.hasPrefix(typed) }
    }
}

/// One line of work in progress, with the tool doing it.
struct Step: Hashable {
    let text: String
    let tool: Tool

    static func plan(_ kind: Kind) -> [Step] {
        switch kind {
        case .concepts:
            [Step(text: "Reading the brief and the brand", tool: .research),
             Step(text: "Writing three angles", tool: .write),
             Step(text: "Shooting in Palmix light", tool: .image),
             Step(text: "Sizing for Story, Square and Feed", tool: .layout)]
        case .read:
            [Step(text: "Reading the page and their ads", tool: .research),
             Step(text: "Comparing with Palmix", tool: .research),
             Step(text: "Writing it down plainly", tool: .write)]
        case .storyboard:
            [Step(text: "Finding the hook", tool: .write),
             Step(text: "Framing three shots", tool: .image),
             Step(text: "Timing it to 15 seconds", tool: .video)]
        case .post:
            [Step(text: "Looking at what worked last month", tool: .research),
             Step(text: "Writing in Palmix's voice", tool: .write),
             Step(text: "Picking the picture", tool: .image),
             Step(text: "Finding the best slot", tool: .publish)]
        }
    }
}

// MARK: - Answers

struct Answer: Equatable {
    struct Card: Hashable {
        var image: String?
        var title: String
        var line: String
        var stamp: String? = nil
    }

    let kind: Kind
    let heading: String
    let cards: [Card]
    /// For a read: what they own, what they leave open, what to do.
    var rows: [(String, String)] = []
    var body: String = ""

    static func == (a: Answer, b: Answer) -> Bool {
        a.kind == b.kind && a.heading == b.heading && a.cards == b.cards
    }

    static func make(_ kind: Kind, ask: String, place: Place) -> Answer {
        switch kind {
        case .concepts:
            return Answer(kind: kind, heading: "Three ways in", cards: [
                Card(image: "energy", title: "Your 3pm, without the crash.",
                     line: "Watermelon and coconut. Sugar you can read on the label."),
                Card(image: "chill", title: "Slow is a flavour.",
                     line: "Pineapple, coconut and nothing to prove."),
                Card(image: "glow", title: "Summer, bottled honestly.",
                     line: "Mango and coconut, cold from the fridge."),
            ])
        case .read:
            let them = place.host == nil ? "Vita Coco" : place.name
            return Answer(
                kind: kind,
                heading: place.host == nil ? "Vita Coco sells sport. Nobody owns calm." : "\(them) sells a feeling, not a product.",
                cards: [],
                rows: [
                    ("They own", place.host == nil
                        ? "Hydration after the gym. Athletes, sweat, big claims."
                        : "One clear promise above the fold, and a product you can picture in your hand."),
                    ("They leave open", place.host == nil
                        ? "The slow moments: a 3pm break, a beach, a Sunday. Nobody speaks to those."
                        : "Proof from real people. No faces, no voices, no day-in-the-life."),
                    ("Your move", "Palmix as the calm drink. Real hands, real light, no gym. Start with Chill and Glow."),
                ],
                body: "Read from their site, 14 live ads and 40 recent comments."
            )
        case .storyboard:
            return Answer(kind: kind, heading: "Fifteen seconds, three shots", cards: [
                Card(image: "fun", title: "The pop", line: "Cap twists off close to the mic. Loud, then quiet.", stamp: "0:00"),
                Card(image: "glow", title: "The pour", line: "Over ice, slowly, in window light.", stamp: "0:03"),
                Card(image: "recover", title: "The line", line: "“Tastes like a day off.” Logo, then nothing.", stamp: "0:11"),
            ])
        case .post:
            return Answer(kind: kind, heading: "Ready for Tuesday, 9:00", cards: [
                Card(image: "focus", title: "Palmix",
                     line: "We tested our new Focus flavour on the people who make it. Verdict: it tastes like the first quiet hour of the day. Coconut water, a little coconut, nothing else. Out next week."),
            ])
        }
    }
}

// MARK: - The layer over the page

/// Everything Figaro draws, laid over the page area only: the column of tabs
/// is not what Figaro is working on.
struct FigaroLayer: View {
    @ObservedObject var browser: Browser
    @ObservedObject var figaro = Figaro.shared
    let leading: CGFloat
    let top: CGFloat

    var body: some View {
        ZStack {
            if figaro.stage == .working || figaro.stage == .answered {
                Spread(figaro: figaro)
                    .transition(.opacity)
            }

            if figaro.stage == .asking {
                Composer(figaro: figaro)
                    .onDrop(of: [.image, .url, .fileURL], isTargeted: nil) { providers in
                        figaro.take(drop: providers, on: browser.active)
                    }
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .padding(.bottom, 28)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            ToastHost()
                .frame(maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, figaro.stage == .asking ? 250 : 28)

            if figaro.stage == .resting, browser.active?.immersed != true {
                FigaroPill { figaro.open(on: browser.active) }
                    .onDrop(of: [.image, .url, .fileURL], isTargeted: nil) { providers in
                        figaro.take(drop: providers, on: browser.active)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                    .padding(.leading, 20)
                    .padding(.bottom, 20)
                    .transition(.scale(scale: 0.9, anchor: .bottomLeading).combined(with: .opacity))
            }
        }
        .padding(.leading, leading)
        .padding(.top, top)
        .animation(Motion.settle, value: figaro.stage)
    }
}

/// The pill in the corner. The whole toolkit, folded into one word.
private struct FigaroPill: View {
    let action: () -> Void
    @State private var over = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                ZStack {
                    Circle().fill(Palette.ink)
                    Image(systemName: "sparkle")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Palette.ground)
                }
                .frame(width: 22, height: 22)
                Text("Ask Figaro")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Palette.ink)
                Text("⌘J")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Palette.muted)
                    .padding(.trailing, 4)
            }
            .padding(.leading, 6)
            .padding(.trailing, 12)
            .frame(height: 34)
            .background(Capsule().fill(Palette.ground))
            .overlay(Capsule().strokeBorder(Palette.hairline, lineWidth: 1))
            .shadow(color: .black.opacity(over ? 0.14 : 0.08), radius: over ? 18 : 12, y: over ? 8 : 5)
            .offset(y: over ? -2 : 0)
        }
        .buttonStyle(.plain)
        .onHover { hovering in withAnimation(Motion.settle) { over = hovering } }
        .help("Ask Figaro (⌘J)")
    }
}

// MARK: - Asking

private struct Composer: View {
    @ObservedObject var figaro: Figaro
    @FocusState private var focused: Bool

    private var slashing: Bool { figaro.draft.hasPrefix("/") }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                ZStack {
                    Circle().fill(Palette.ink)
                    Image(systemName: "sparkle")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Palette.ground)
                }
                .frame(width: 22, height: 22)
                Text("Figaro")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                Text(figaro.place.label)
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.muted)
                    .lineLimit(1)
                Spacer(minLength: 0)
                // Voice: Figaro can be talked to. A look for now; it listens once Penrose is in.
                IconButton(symbol: "mic", help: "Talk to Figaro") {
                    ZahirStore.shared.toast("Voice comes with the Penrose connection", symbol: "mic")
                }
                Button { figaro.close() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Palette.muted)
                        .frame(width: 24, height: 24)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)

            Group {
                if Snapshot.running {
                    Text(figaro.draft.isEmpty ? "What should we make?" : figaro.draft)
                        .foregroundStyle(figaro.draft.isEmpty ? Palette.ink.opacity(0.3) : Palette.ink)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    TextField("What should we make?", text: $figaro.draft)
                        .textFieldStyle(.plain)
                        .foregroundStyle(Palette.ink)
                        .focused($focused)
                        .onSubmit { figaro.submit() }
                }
            }
                .font(.system(size: 17))
                .padding(.horizontal, 18)
                .padding(.top, 14)
                .padding(.bottom, 14)

            if let attached = figaro.attachment {
                HStack(spacing: 6) {
                    Image(systemName: "paperclip").font(.system(size: 11, weight: .medium))
                    Text(attached).font(.system(size: 12, weight: .medium)).lineLimit(1)
                    Button { figaro.attachment = nil } label: {
                        Image(systemName: "xmark").font(.system(size: 9, weight: .bold))
                    }
                    .buttonStyle(.plain)
                }
                .foregroundStyle(Palette.ink)
                .padding(.horizontal, 10)
                .frame(height: 26)
                .background(Capsule().fill(Palette.wash))
                .padding(.horizontal, 16)
                .padding(.bottom, 10)
                .transition(.scale(scale: 0.9).combined(with: .opacity))
            }

            Rectangle().fill(Palette.hairline).frame(height: 1)

            Group {
                if slashing {
                    tools
                } else {
                    intents
                }
            }
            .padding(12)
            .animation(Motion.settle, value: slashing)

            Text(slashing ? "Return to use a tool   esc to close" : "Type / for tools   esc to close")
                .font(.system(size: 11))
                .foregroundStyle(Palette.muted)
                .padding(.horizontal, 18)
                .padding(.bottom, 12)
        }
        .frame(width: 600)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Palette.ground))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(Palette.hairline, lineWidth: 1))
        .shadow(color: .black.opacity(0.12), radius: 40, y: 16)
        .onAppear { DispatchQueue.main.async { focused = true } }
    }

    private var intents: some View {
        Flow(spacing: 6, line: 6) {
            ForEach(figaro.place.intents, id: \.self) { intent in
                Chip(text: intent.title) { figaro.pick(intent) }
            }
            if figaro.place.host != nil {
                // Make ours: point at one thing on this page (see ZahirClip.swift).
                Chip(text: "Point at something  ⇧⌘E") {
                    figaro.close()
                    ZahirNav.browser?.toggleClipping()
                }
            }
        }
    }

    private var tools: some View {
        VStack(spacing: 2) {
            ForEach(Tool.matching(figaro.draft), id: \.self) { tool in
                ToolRow(tool: tool) {
                    figaro.draft = tool.command + " "
                    focused = true
                }
            }
        }
    }
}

private struct ToolRow: View {
    let tool: Tool
    let action: () -> Void
    @State private var over = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: tool.symbol)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Palette.ink)
                    .frame(width: 30, height: 30)
                    .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Palette.wash))
                Text(tool.name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                Text(tool.blurb)
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.muted)
                Spacer(minLength: 0)
                Text(tool.command)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(Palette.muted)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(over ? Palette.hover : .clear))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { over = $0 }
    }
}

// MARK: - The spread: work in progress, then the answer

private struct Spread: View {
    @ObservedObject var figaro: Figaro

    var body: some View {
        ZStack {
            Rectangle()
                .fill(Palette.ground.opacity(0.9))
                .onTapGesture { figaro.close() }

            // ImageRenderer draws nothing inside a ScrollView; a snapshot gets
            // the content straight.
            if Snapshot.running {
                content
            } else {
                ScrollView(.vertical, showsIndicators: false) { content }
            }
        }
    }

    private var content: some View {
        VStack(spacing: 28) {
            header
            if let answer = figaro.answer {
                AnswerView(answer: answer)
                footer
            } else {
                progress
            }
        }
        .padding(.vertical, 48)
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity)
    }

    private var header: some View {
        VStack(spacing: 10) {
            Text(figaro.ask)
                .font(.system(size: 26, weight: .semibold))
                .tracking(-0.4)
                .foregroundStyle(Palette.ink)
                .multilineTextAlignment(.center)
            HStack(spacing: 6) {
                Text("Figaro \(figaro.place.label)")
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.muted)
                ForEach(used, id: \.self) { tool in
                    HStack(spacing: 4) {
                        Image(systemName: tool.symbol).font(.system(size: 10, weight: .medium))
                        Text(tool.name).font(.system(size: 11, weight: .medium))
                    }
                    .foregroundStyle(Palette.ink.opacity(0.7))
                    .padding(.horizontal, 8)
                    .frame(height: 22)
                    .background(Capsule().fill(Palette.wash))
                    .transition(.scale(scale: 0.8).combined(with: .opacity))
                }
            }
        }
        .frame(maxWidth: 720)
    }

    /// The tools that have been reached for so far, once each.
    private var used: [Tool] {
        var seen: [Tool] = []
        for step in figaro.steps.prefix(max(figaro.done, 1)) where !seen.contains(step.tool) {
            seen.append(step.tool)
        }
        return seen
    }

    private var progress: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Array(figaro.steps.enumerated()), id: \.offset) { index, step in
                HStack(spacing: 12) {
                    ZStack {
                        Circle().strokeBorder(Palette.hairline, lineWidth: 1)
                        if index < figaro.done {
                            Circle().fill(Palette.ink)
                            Image(systemName: "checkmark")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(Palette.ground)
                        } else if index == figaro.done {
                            ProgressView().controlSize(.mini)
                        }
                    }
                    .frame(width: 20, height: 20)
                    Text(step.text)
                        .font(.system(size: 15))
                        .foregroundStyle(index <= figaro.done ? Palette.ink : Palette.faint)
                }
            }
        }
        .frame(width: 360, alignment: .leading)
        .padding(.top, 12)
    }

    private var footer: some View {
        HStack(spacing: 8) {
            Button { figaro.close() } label: {
                Text("Keep")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Palette.ground)
                    .padding(.horizontal, 20)
                    .frame(height: 38)
                    .background(Capsule().fill(Palette.ink))
            }
            .buttonStyle(.plain)
            Chip(text: "Try another way") {
                if let answer = figaro.answer { figaro.pick(Intent(title: figaro.ask, kind: answer.kind)) }
            }
            Chip(text: "Close") { figaro.close() }
        }
    }
}

struct AnswerView: View {
    let answer: Answer

    var body: some View {
        switch answer.kind {
        case .concepts: concepts
        case .storyboard: storyboard
        case .read: read
        case .post: post
        }
    }

    private var concepts: some View {
        VStack(spacing: 18) {
            HStack(alignment: .top, spacing: 22) {
                ForEach(Array(answer.cards.enumerated()), id: \.offset) { index, card in
                    Dealt(index: index) {
                        ConceptCard(number: index + 1, card: card)
                    }
                }
            }
            HStack(spacing: 6) {
                Text("Sized for")
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.muted)
                ForEach(["Story 1080×1920", "Square 1080×1080", "Feed 1200×628"], id: \.self) { size in
                    Text(size)
                        .font(.system(size: 11, weight: .medium).monospacedDigit())
                        .foregroundStyle(Palette.ink.opacity(0.75))
                        .padding(.horizontal, 8)
                        .frame(height: 22)
                        .background(Capsule().fill(Palette.wash))
                }
            }
        }
    }

    private var storyboard: some View {
        HStack(alignment: .top, spacing: 18) {
            ForEach(Array(answer.cards.enumerated()), id: \.offset) { index, card in
                Dealt(index: index) {
                    VStack(alignment: .leading, spacing: 10) {
                        Shot(name: card.image)
                            .frame(width: 180, height: 320)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay(alignment: .topLeading) {
                                Text(card.stamp ?? "")
                                    .font(.system(size: 11, weight: .semibold).monospacedDigit())
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 8)
                                    .frame(height: 22)
                                    .background(Capsule().fill(.black.opacity(0.55)))
                                    .padding(10)
                            }
                        Text(card.title)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Palette.ink)
                        Text(card.line)
                            .font(.system(size: 13))
                            .foregroundStyle(Palette.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(width: 180)
                }
            }
        }
    }

    private var read: some View {
        Dealt(index: 0, crooked: false) {
            VStack(alignment: .leading, spacing: 0) {
                Text(answer.heading)
                    .font(.system(size: 22, weight: .semibold))
                    .tracking(-0.3)
                    .foregroundStyle(Palette.ink)
                    .padding(.bottom, 6)
                Text(answer.body)
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.muted)
                    .padding(.bottom, 18)
                ForEach(Array(answer.rows.enumerated()), id: \.offset) { index, row in
                    VStack(alignment: .leading, spacing: 0) {
                        Rectangle().fill(Palette.hairline).frame(height: 1)
                        HStack(alignment: .firstTextBaseline, spacing: 16) {
                            Text(row.0)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(index == 2 ? Palette.ink : Palette.muted)
                                .frame(width: 120, alignment: .leading)
                            Text(row.1)
                                .font(.system(size: 15))
                                .foregroundStyle(Palette.ink)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.vertical, 14)
                    }
                }
                HStack(spacing: 10) {
                    ForEach(["chill", "glow"], id: \.self) { name in
                        Shot(name: name)
                            .frame(width: 96, height: 96)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    Text("Start here: Chill and Glow, shot in real light.")
                        .font(.system(size: 13))
                        .foregroundStyle(Palette.muted)
                        .padding(.leading, 6)
                }
                .padding(.top, 6)
            }
            .padding(28)
            .frame(width: 620, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Palette.ground))
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(Palette.hairline, lineWidth: 1))
            .shadow(color: .black.opacity(0.07), radius: 30, y: 12)
        }
    }

    private var post: some View {
        let card = answer.cards[0]
        return Dealt(index: 0, crooked: false) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    ZStack {
                        Circle().fill(Palette.ink)
                        Text("P").font(.system(size: 14, weight: .semibold)).foregroundStyle(Palette.ground)
                    }
                    .frame(width: 36, height: 36)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(card.title).font(.system(size: 14, weight: .semibold)).foregroundStyle(Palette.ink)
                        Text("LinkedIn · Tuesday 9:00").font(.system(size: 12)).foregroundStyle(Palette.muted)
                    }
                }
                Text(card.line)
                    .font(.system(size: 15))
                    .lineSpacing(3)
                    .foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Shot(name: card.image)
                    .frame(width: 472, height: 300)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                HStack(spacing: 8) {
                    Text("Schedule")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Palette.ground)
                        .padding(.horizontal, 16)
                        .frame(height: 32)
                        .background(Capsule().fill(Palette.ink))
                    Chip(text: "Also for Instagram")
                    Chip(text: "Shorter")
                }
            }
            .padding(24)
            .frame(width: 520, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Palette.ground))
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(Palette.hairline, lineWidth: 1))
            .shadow(color: .black.opacity(0.07), radius: 30, y: 12)
        }
    }
}

/// One ad concept: the picture, a numbered badge, the line, and what to do
/// with it next.
struct ConceptCard: View {
    let number: Int
    let card: Answer.Card

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Shot(name: card.image)
                .frame(width: 240, height: 300)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(alignment: .topLeading) {
                    Text("\(number)")
                        .font(.system(size: 12, weight: .semibold).monospacedDigit())
                        .foregroundStyle(Palette.ink)
                        .frame(width: 26, height: 26)
                        .background(Circle().fill(Palette.ground))
                        .overlay(Circle().strokeBorder(Palette.hairline, lineWidth: 1))
                        .padding(10)
                }
                .padding(8)
            VStack(alignment: .leading, spacing: 6) {
                Text(card.title)
                    .font(.system(size: 17, weight: .semibold))
                    .tracking(-0.2)
                    .foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text(card.line)
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 14)
            .padding(.top, 8)
            HStack(spacing: 6) {
                Chip(text: "Resize") { Studio.open(card, in: .layout) }
                Chip(text: "Animate") { Studio.open(card, in: .video) }
                Chip(text: "Edit") { Studio.open(card, in: .image) }
            }
            .padding(14)
        }
        .frame(width: 256)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Palette.ground))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(Palette.hairline, lineWidth: 1))
    }
}

// MARK: - Home

/// A blank tab in Zahir: a few sentences about what Figaro did and what is
/// waiting for you, under the field. Point at a part of them and the work
/// floats in around the page; click it and it opens.
struct ZahirHome: View {
    @ObservedObject var figaro = Figaro.shared
    @ObservedObject var store = ZahirStore.shared
    @State private var peeking: Door?

    init(peeking: Door? = nil) {
        _peeking = State(initialValue: peeking)
    }

    /// What a phrase in the sentences opens.
    enum Door: Hashable {
        case answer(Kind)
        case review
        case route(ZahirRoute)
    }

    private enum Token: Hashable {
        case word(String)
        case link(String, Door, trailing: String)
    }

    private static func tokens(_ build: (inout [Token]) -> Void) -> [Token] {
        var out: [Token] = []
        build(&out)
        return out
    }

    private static func words(_ s: String, _ out: inout [Token]) {
        s.split(separator: " ").forEach { out.append(.word(String($0))) }
    }

    private let made: [Token] = tokens { out in
        words("While you were away, Figaro made", &out)
        out.append(.link("three ads for Energy", .answer(.concepts), trailing: ", "))
        words("read", &out)
        out.append(.link("what Vita Coco is doing", .answer(.read), trailing: ", "))
        words("cut", &out)
        out.append(.link("a TikTok for Glow", .answer(.storyboard), trailing: ", "))
        words("and wrote", &out)
        out.append(.link("Tuesday's post", .answer(.post), trailing: "."))
    }

    private let waiting: [Token] = tokens { out in
        out.append(.link("Two of the ads", .review, trailing: " "))
        words("need your OK before Friday.", &out)
        out.append(.link("The Glow launch", .route(.playbooks), trailing: " "))
        words("starts on the 3rd, and one rule in your", &out)
        out.append(.link("brand room", .route(.brand), trailing: " "))
        words("is switched off.", &out)
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(peeks, id: \.self) { peek in
                    PeekCard(peek: peek)
                        .position(x: geo.size.width * peek.x, y: geo.size.height * peek.y)
                        .transition(.scale(scale: 0.9).combined(with: .opacity))
                }

                VStack(alignment: .leading, spacing: 14) {
                    Text(store.brand.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Palette.ink)
                    paragraph(made)
                    paragraph(waiting)
                    PrimaryButton(title: "Start something") { figaro.open(on: nil) }
                        .padding(.top, 8)
                }
                .frame(width: Metrics.fieldWidth - 8, alignment: .leading)
                .position(x: geo.size.width / 2, y: geo.size.height / 2 + 130)
            }
        }
        .opacity(figaro.showing ? 0 : 1)
        .animation(Motion.settle, value: figaro.showing)
    }

    private func paragraph(_ tokens: [Token]) -> some View {
        Flow(spacing: 0, line: 5) {
            ForEach(Array(tokens.enumerated()), id: \.offset) { _, token in
                switch token {
                case .word(let text):
                    Text(text + " ")
                        .font(.system(size: 15))
                        .foregroundStyle(Palette.muted)
                case .link(let text, let door, let trailing):
                    LinkWords(text: text, trailing: trailing) { hovering in
                        withAnimation(.spring(response: 0.42, dampingFraction: 0.8)) {
                            peeking = hovering ? door : (peeking == door ? nil : peeking)
                        }
                    } action: {
                        peeking = nil
                        open(door)
                    }
                }
            }
        }
    }

    private func open(_ door: Door) {
        switch door {
        case .answer(let kind): figaro.show(kind)
        case .review: figaro.show(.concepts)
        case .route(let route): ZahirNav.open(route)
        }
    }

    private var peeks: [Peek] {
        switch peeking {
        case .answer(.concepts):
            [Peek(image: "energy", title: "Your 3pm, without the crash.", x: 0.17, y: 0.24, tilt: -4),
             Peek(image: "chill", title: "Slow is a flavour.", x: 0.83, y: 0.22, tilt: 3),
             Peek(image: "glow", title: "Summer, bottled honestly.", x: 0.8, y: 0.8, tilt: -2.5)]
        case .answer(.read):
            [Peek(image: nil, title: "Vita Coco sells sport. Nobody owns calm.", x: 0.2, y: 0.22, tilt: -3),
             Peek(image: "chill", title: "Your move: the calm drink.", x: 0.82, y: 0.78, tilt: 2.5)]
        case .answer(.storyboard):
            [Peek(image: "fun", title: "0:00  The pop", x: 0.16, y: 0.26, tilt: -3.5, tall: true),
             Peek(image: "glow", title: "0:03  The pour", x: 0.84, y: 0.26, tilt: 3, tall: true)]
        case .answer(.post):
            [Peek(image: "focus", title: "Tuesday 9:00 · LinkedIn", x: 0.82, y: 0.24, tilt: 3),
             Peek(image: nil, title: "“It tastes like the first quiet hour of the day.”", x: 0.19, y: 0.78, tilt: -2)]
        case .review:
            [Peek(image: "energy", title: "Waiting for your OK · Instagram", x: 0.17, y: 0.26, tilt: -3),
             Peek(image: "chill", title: "Waiting for your OK · Instagram", x: 0.83, y: 0.26, tilt: 2.5)]
        case .route(.playbooks):
            [Peek(image: nil, title: "Glow launch · 6 steps · starts on the 3rd", x: 0.19, y: 0.24, tilt: -2.5),
             Peek(image: "glow", title: "Step 1 of 6: the TikTok", x: 0.83, y: 0.78, tilt: 3, tall: true)]
        case .route(.brand):
            [Peek(image: nil, title: "Off: No gym, no sweat, no 'performance'", x: 0.8, y: 0.24, tilt: 2.5)]
        default:
            []
        }
    }
}

private struct Peek: Hashable {
    let image: String?
    let title: String
    let x: CGFloat
    let y: CGFloat
    let tilt: Double
    var tall = false
}

private struct PeekCard: View {
    let peek: Peek

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let image = peek.image {
                Shot(name: image)
                    .frame(width: peek.tall ? 150 : 230, height: peek.tall ? 240 : 160)
                    .clipped()
            }
            Text(peek.title)
                .font(.system(size: peek.image == nil ? 17 : 13, weight: peek.image == nil ? .semibold : .medium))
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
                .padding(peek.image == nil ? 22 : 12)
                .frame(width: peek.image == nil ? 240 : (peek.tall ? 150 : 230), alignment: .leading)
        }
        .background(Palette.ground)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Palette.hairline, lineWidth: 1))
        .shadow(color: .black.opacity(0.1), radius: 26, y: 12)
        .rotationEffect(.degrees(peek.tilt))
        .allowsHitTesting(false)
    }
}

/// A phrase in the sentence that is also a door: ink, underlined, and
/// reported when the pointer is over it.
private struct LinkWords: View {
    let text: String
    let trailing: String
    let hover: (Bool) -> Void
    let action: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            Text(text)
                .font(.system(size: 15))
                .foregroundStyle(Palette.ink)
                .underline(true, color: Palette.faint)
                .onHover(perform: hover)
                .onTapGesture(perform: action)
                .onContinuousHover { phase in
                    if case .active = phase { NSCursor.pointingHand.set() } else { NSCursor.arrow.set() }
                }
            Text(trailing)
                .font(.system(size: 15))
                .foregroundStyle(Palette.muted)
        }
    }
}

// MARK: - Snapshot

/// `ZAHIR_SNAPSHOT=<folder>` renders each Zahir surface to a PNG and quits,
/// so the surfaces can be looked at without a screen recording permission.
@MainActor
enum Snapshot {
    static let folder = ProcessInfo.processInfo.environment["ZAHIR_SNAPSHOT"]
    static var running: Bool { folder != nil }

    static func runIfAsked() {
        guard let folder else { return }
        let dir = URL(fileURLWithPath: folder, isDirectory: true)
        FileHandle.standardError.write("snapshot to \(dir.path)\n".data(using: .utf8)!)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let figaro = Figaro.shared
        let size = CGSize(width: 1180, height: 740)
        let norma = Place(host: "norma.co", title: "Norma")

        func save(_ name: String, _ view: some View) {
            let framed = view.frame(width: size.width, height: size.height).background(Palette.ground)
            let renderer = ImageRenderer(content: framed)
            renderer.scale = 2
            guard let image = renderer.nsImage,
                  let tiff = image.tiffRepresentation,
                  let rep = NSBitmapImageRep(data: tiff),
                  let png = rep.representation(using: .png, properties: [:]) else {
                FileHandle.standardError.write("snapshot \(name): no image\n".data(using: .utf8)!)
                return
            }
            do { try png.write(to: dir.appendingPathComponent(name + ".png")) }
            catch { FileHandle.standardError.write("snapshot \(name): \(error)\n".data(using: .utf8)!) }
        }

        save("1-home", ZahirHome())
        save("2-home-peek-ads", ZahirHome(peeking: .answer(.concepts)))
        save("3-home-peek-review", ZahirHome(peeking: .review))
        figaro.stage(.asking, kind: .concepts, place: norma)
        save("4-composer-on-page", Composer(figaro: figaro).frame(maxHeight: .infinity, alignment: .bottom).padding(.bottom, 28))
        figaro.stage(.asking, kind: .concepts, draft: "/")
        save("5-composer-tools", Composer(figaro: figaro).frame(maxHeight: .infinity, alignment: .bottom).padding(.bottom, 28))
        figaro.stage(.working, kind: .concepts, done: 2)
        save("6-working", Spread(figaro: figaro))
        for (name, kind) in [("7-ads", Kind.concepts), ("8-read", .read), ("9-video", .storyboard), ("10-post", .post)] {
            figaro.stage(.answered, kind: kind)
            save(name, Spread(figaro: figaro))
        }
        save("11-pill", FigaroPill {}.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading).padding(20))
        // Every surface's own states (see each surface's `snapshots`).
        let only = ProcessInfo.processInfo.environment["ZAHIR_SNAPSHOT_ONLY"]
        for (name, view) in HireFigaro.snapshots + BrandRoom.snapshots + FigaroThread.snapshots
            + ImageStudio.snapshots + VideoStudio.snapshots + LayoutStudio.snapshots + CopyDesk.snapshots
            + ResearchBoard.snapshots + CalendarSurface.snapshots + ResultsSurface.snapshots
            + LibrarySurface.snapshots + InboxSurface.snapshots + PlaybooksSurface.snapshots
        where only == nil || name.hasPrefix(only!) {
            save(name, view)
        }
        exit(0)
    }
}

// MARK: - Dropping things on Figaro

extension Figaro {
    /// An image or a link dropped on the pill or the composer.
    func take(drop providers: [NSItemProvider], on tab: Tab?) -> Bool {
        guard let provider = providers.first else { return false }
        if provider.canLoadObject(ofClass: NSImage.self) {
            _ = provider.loadObject(ofClass: NSImage.self) { object, _ in
                guard let image = object as? NSImage else { return }
                DispatchQueue.main.async {
                    let source = tab?.address?.host()?.replacingOccurrences(of: "www.", with: "") ?? "a drop"
                    ZahirStore.shared.reference = ZReference(image: image, source: source, note: "Dropped on Figaro")
                    self.attach("A picture from \(source)", on: tab)
                }
            }
            return true
        }
        if provider.canLoadObject(ofClass: URL.self) {
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                guard let url else { return }
                DispatchQueue.main.async {
                    self.attach(url.host()?.replacingOccurrences(of: "www.", with: "") ?? url.absoluteString, on: tab)
                }
            }
            return true
        }
        return false
    }

    private func attach(_ label: String, on tab: Tab?) {
        if !showing { open(on: tab) }
        attachment = label
    }
}
