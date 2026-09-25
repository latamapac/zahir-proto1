import SwiftUI

// Video studio: the Higgsfield part of Zahir. A sentence becomes a
// storyboard, a storyboard becomes a timeline, and Render turns it into a
// clip. Fake data only — a preset swaps between a few storyboards written
// out below, the render finishes on a clock, and the voice rows don't
// actually play anything back.

struct VideoStudio: View {
    @ObservedObject var store = ZahirStore.shared

    @State private var brief: String
    @State private var preset: VideoPreset
    @State private var shots: [VideoShot]
    @State private var selectedShot: Int
    @State private var playhead: Double
    @State private var voice = 0
    @State private var playingVoice: Int?
    @State private var captionsOn = true
    @State private var musicMood = "Sunlit"
    @State private var length = "15s"
    @State private var format = "TikTok 9:16"
    @State private var regenerating: VideoShot.ID?
    @State private var renderState: VideoRenderState
    @State private var renderProgress: Double

    @State private var playTask: Task<Void, Never>?
    @State private var voiceTask: Task<Void, Never>?
    @State private var renderTask: Task<Void, Never>?
    @State private var regenTask: Task<Void, Never>?

    private let totalDuration: Double = 15
    private let cardWidth: CGFloat = 118
    private let rowHeight: CGFloat = 30
    private let labelWidth: CGFloat = 72
    private var trackAreaHeight: CGFloat { 4 * rowHeight + 3 * 8 }

    /// Init params for Snapshot: the preset picked, the shot selected, the
    /// playhead's time, and how far the render has got.
    init(preset: VideoPreset = .ugcTestimonial, selectedShot: Int = 0, playhead: Double = 0,
         renderState: VideoRenderState = .idle, renderProgress: Double = 0) {
        _brief = State(initialValue: "A 15-second TikTok for the Glow launch")
        _preset = State(initialValue: preset)
        _shots = State(initialValue: preset.shots)
        _selectedShot = State(initialValue: selectedShot)
        _playhead = State(initialValue: playhead)
        _renderState = State(initialValue: renderState)
        _renderProgress = State(initialValue: renderProgress)
    }

    var body: some View {
        Group {
            if Snapshot.running {
                content
            } else {
                ScrollView(.vertical, showsIndicators: false) { content }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.ground)
        .onAppear(perform: takeHandoff)
        .onDisappear {
            playTask?.cancel()
            voiceTask?.cancel()
            renderTask?.cancel()
            regenTask?.cancel()
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 18) {
            title
            HStack(alignment: .top, spacing: 20) {
                VStack(alignment: .leading, spacing: 14) {
                    briefField
                    Flow(spacing: 8, line: 8) {
                        ForEach(VideoPreset.allCases, id: \.self) { p in
                            Choice(text: p.title, on: preset == p) { selectPreset(p) }
                        }
                    }
                    storyboardRow
                    timeline
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                rightPanel
                    .frame(width: 280, alignment: .leading)
            }
        }
        .padding(.horizontal, 32)
        .padding(.top, 24)
        .padding(.bottom, 24)
    }

    /// A card handed in from Figaro's storyboard answer ("Animate") seeds the
    /// brief and the first shot, the way the rest of Zahir carries work
    /// between tools.
    private func takeHandoff() {
        guard !Snapshot.running, let card = store.handoff else { return }
        brief = card.title
        if let image = card.image, !shots.isEmpty {
            shots[0].image = image
        }
        store.handoff = nil
    }

    // MARK: - Header

    private var title: some View {
        Text("Video studio")
            .font(.system(size: 28, weight: .semibold))
            .tracking(-0.5)
            .foregroundStyle(Palette.ink)
    }

    private var briefField: some View {
        HStack(spacing: 10) {
            Image(systemName: "text.bubble")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Palette.muted)
            Group {
                if Snapshot.running {
                    Text(brief)
                        .foregroundStyle(Palette.ink)
                } else {
                    TextField("A 15-second TikTok for the Glow launch", text: $brief)
                        .textFieldStyle(.plain)
                        .foregroundStyle(Palette.ink)
                }
            }
            .font(.system(size: 14))
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 14)
        .frame(height: 42)
        .frame(maxWidth: 520)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Palette.wash))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Palette.hairline, lineWidth: 1))
    }

    private func selectPreset(_ p: VideoPreset) {
        withAnimation(Motion.settle) {
            preset = p
            shots = p.shots
            selectedShot = 0
        }
    }

    // MARK: - Storyboard

    private var storyboardRow: some View {
        HStack(alignment: .top, spacing: 14) {
            ForEach(Array(shots.enumerated()), id: \.element.id) { index, shot in
                Dealt(index: index) {
                    ShotCard(
                        shot: shot,
                        width: cardWidth,
                        selected: index == selectedShot,
                        regenerating: regenerating == shot.id,
                        onSelect: { withAnimation(Motion.quick) { selectedShot = index } },
                        onRegenerate: { regenerate(shot) }
                    )
                }
            }
        }
    }

    private func regenerate(_ shot: VideoShot) {
        let pool = ["chill", "energy", "focus", "fun", "glow", "recover"]
        regenTask?.cancel()
        withAnimation(Motion.quick) { regenerating = shot.id }
        regenTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 550_000_000)
            guard !Task.isCancelled else { return }
            if let i = shots.firstIndex(where: { $0.id == shot.id }) {
                shots[i].image = pool.filter { $0 != shots[i].image }.randomElement() ?? shots[i].image
            }
            withAnimation(Motion.settle) { regenerating = nil }
        }
    }

    // MARK: - Timeline

    private var timeline: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHead(title: "Timeline") {
                IconButton(symbol: "play.fill", help: "Play", action: play)
            }
            ruler
            GeometryReader { geo in
                let trackWidth = max(geo.size.width - labelWidth, 1)
                ZStack(alignment: .topLeading) {
                    VStack(alignment: .leading, spacing: 8) {
                        trackRow(label: "Video") { videoTrack(width: trackWidth) }
                        trackRow(label: "Voice") { voiceTrack(width: trackWidth) }
                        trackRow(label: "Music") { musicTrack(width: trackWidth) }
                        trackRow(label: "Captions") { captionsTrack(width: trackWidth) }
                    }
                    playheadMark(trackWidth: trackWidth)
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let x = value.location.x - labelWidth
                            let clamped = min(max(x, 0), trackWidth)
                            playhead = Double(clamped / trackWidth) * totalDuration
                        }
                )
            }
            .frame(height: trackAreaHeight)
        }
        .zCard(radius: 16, padding: 16)
    }

    private var ruler: some View {
        HStack(spacing: 0) {
            Color.clear.frame(width: labelWidth)
            HStack(spacing: 0) {
                ForEach(Array(stride(from: 0, through: Int(totalDuration), by: 3)), id: \.self) { t in
                    Text(timecode(Double(t)))
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(Palette.muted)
                    if t < Int(totalDuration) { Spacer(minLength: 0) }
                }
            }
        }
    }

    private func trackRow<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 10) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Palette.muted)
                .lineLimit(1)
                .fixedSize()
                .frame(width: labelWidth - 10, alignment: .leading)
            content()
        }
        .frame(height: rowHeight)
    }

    private func videoTrack(width: CGFloat) -> some View {
        HStack(spacing: 2) {
            ForEach(shots) { shot in
                Shot(name: shot.image)
                    .frame(width: max(width * CGFloat(shot.duration / totalDuration) - 2, 4), height: rowHeight)
                    .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
            }
        }
        .frame(width: width, height: rowHeight, alignment: .leading)
    }

    private func voiceTrack(width: CGFloat) -> some View {
        HStack(spacing: 2) {
            ForEach(Array(Self.waveform.enumerated()), id: \.offset) { _, v in
                Capsule()
                    .fill(Palette.ink.opacity(0.5))
                    .frame(
                        width: max((width - CGFloat(Self.waveform.count - 1) * 2) / CGFloat(Self.waveform.count), 1),
                        height: max(rowHeight * v, 3)
                    )
            }
        }
        .frame(width: width, height: rowHeight)
    }

    private func musicTrack(width: CGFloat) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "music.note")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Palette.ink.opacity(0.7))
            Text(musicMood)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Palette.ink.opacity(0.8))
        }
        .padding(.horizontal, 12)
        .frame(width: width, height: rowHeight, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Palette.wash))
    }

    private func captionsTrack(width: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            if captionsOn {
                ForEach(Array(Self.captionWords.enumerated()), id: \.offset) { _, word in
                    Text(word.0)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Palette.ink)
                        .padding(.horizontal, 6)
                        .frame(height: 18)
                        .background(Capsule().fill(Palette.wash))
                        .offset(
                            x: min(width * CGFloat(word.1 / totalDuration), max(width - 34, 0)),
                            y: (rowHeight - 18) / 2
                        )
                }
            } else {
                Text("Off")
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.faint)
                    .offset(y: (rowHeight - 14) / 2)
            }
        }
        .frame(width: width, height: rowHeight, alignment: .leading)
    }

    private func playheadMark(trackWidth: CGFloat) -> some View {
        let x = labelWidth + trackWidth * CGFloat(min(max(playhead / totalDuration, 0), 1))
        return ZStack(alignment: .top) {
            Rectangle().fill(Palette.ink).frame(width: 1.5, height: trackAreaHeight)
            Circle().fill(Palette.ink).frame(width: 10, height: 10).offset(y: -4)
        }
        .offset(x: x - 0.75)
        .allowsHitTesting(false)
    }

    private func play() {
        playTask?.cancel()
        playhead = 0
        playTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 16_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(.linear(duration: 3.0)) { playhead = totalDuration }
        }
    }

    /// Bars for the voice track: a fixed seed, so the shape never changes.
    private static let waveform: [CGFloat] = {
        var seed: UInt64 = 20260924
        func next() -> CGFloat {
            seed = seed &* 6364136223846793005 &+ 1
            return CGFloat((seed >> 33) % 1000) / 1000
        }
        return (0..<56).map { _ in 0.18 + next() * 0.82 }
    }()

    private static let captionWords: [(String, Double)] = [
        ("Tastes", 0.5), ("like", 2), ("a", 3), ("day", 4.5), ("off.", 6),
        ("The", 9), ("pour.", 11), ("Glow.", 13),
    ]

    // MARK: - Right panel

    private var rightPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            voiceSection
            captionsRow
            miniSection(title: "Music mood") {
                Flow(spacing: 8, line: 8) {
                    ForEach(["Sunlit", "Slow", "Upbeat"], id: \.self) { mood in
                        Choice(text: mood, on: musicMood == mood) { musicMood = mood }
                    }
                }
            }
            miniSection(title: "Length") {
                HStack(spacing: 8) {
                    ForEach(["15s", "30s"], id: \.self) { len in
                        Choice(text: len, on: length == len) { length = len }
                    }
                }
            }
            miniSection(title: "Format") {
                Flow(spacing: 8, line: 8) {
                    ForEach(["TikTok 9:16", "Square", "Story"], id: \.self) { fmt in
                        Choice(text: fmt, on: format == fmt) { format = fmt }
                    }
                }
            }
            renderArea
        }
    }

    private func miniSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHead(title: title)
            content()
        }
    }

    private var voiceSection: some View {
        miniSection(title: "Voice") {
            VStack(spacing: 4) {
                ForEach(Array(Self.voices.enumerated()), id: \.offset) { i, label in
                    VoiceRow(
                        label: label,
                        selected: voice == i,
                        playing: playingVoice == i,
                        onSelect: { voice = i },
                        onPlay: { togglePlayVoice(i) }
                    )
                }
            }
        }
    }

    private static let voices = ["Maya · warm, late 20s", "Leo · calm, 30s", "Ana · bright, 20s"]

    private func togglePlayVoice(_ i: Int) {
        voiceTask?.cancel()
        withAnimation(Motion.quick) { playingVoice = i }
        voiceTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_100_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(Motion.quick) { playingVoice = nil }
        }
    }

    private var captionsRow: some View {
        HStack {
            Text("Captions")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Palette.ink)
            Spacer(minLength: 8)
            CaptionsSwitch(on: captionsOn) { withAnimation(Motion.quick) { captionsOn.toggle() } }
        }
    }

    // MARK: - Render

    private var renderArea: some View {
        Group {
            switch renderState {
            case .idle:
                PrimaryButton(title: "Render", symbol: "wand.and.stars", action: render)
            case .rendering:
                renderingCard
            case .ready:
                readyCard
            }
        }
    }

    private var renderingCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Rendering \(Int(renderProgress * 100))%")
                .font(.system(size: 13, weight: .semibold).monospacedDigit())
                .foregroundStyle(Palette.ink)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Palette.wash)
                    Capsule().fill(Palette.ink).frame(width: geo.size.width * renderProgress)
                }
            }
            .frame(height: 4)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Palette.ground))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Palette.hairline, lineWidth: 1))
    }

    private var readyCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                Text("Ready")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Palette.ink)
            }
            HStack(spacing: 8) {
                Chip(text: "Keep", action: keepAsset)
                Chip(text: "Post to TikTok") { store.toast("The calendar arrives in wave 3") }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Palette.ground))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Palette.hairline, lineWidth: 1))
    }

    private func render() {
        renderTask?.cancel()
        withAnimation(Motion.settle) {
            renderState = .rendering
            renderProgress = 0
        }
        renderTask = Task { @MainActor in
            let steps = 24
            for i in 1...steps {
                try? await Task.sleep(nanoseconds: 125_000_000)
                guard !Task.isCancelled else { return }
                withAnimation(Motion.quick) { renderProgress = Double(i) / Double(steps) }
            }
            guard !Task.isCancelled else { return }
            withAnimation(Motion.settle) { renderState = .ready }
        }
    }

    private var channel: String {
        switch format {
        case "TikTok 9:16": "TikTok"
        default: "Instagram"
        }
    }

    private func keepAsset() {
        store.keep(ZAsset(.video, brief.isEmpty ? "Untitled video" : brief, image: shots.first?.image, channel: channel, made: "Now"))
    }

    /// Named states for Snapshot: each is rendered to a PNG for review.
    @MainActor static var snapshots: [(String, AnyView)] {
        [
            ("video-1-storyboard", AnyView(VideoStudio(preset: .ugcTestimonial, selectedShot: 1, playhead: 4).frame(width: 1180, height: 740))),
            ("video-2-rendering", AnyView(VideoStudio(renderState: .rendering, renderProgress: 0.64).frame(width: 1180, height: 740))),
        ]
    }
}

/// "0:04" — every clip here is under a minute, so the minutes are always 0.
private func timecode(_ seconds: Double) -> String {
    let s = Int(seconds.rounded())
    return s < 10 ? "0:0\(s)" : "0:\(s)"
}

// MARK: - Presets and storyboards

enum VideoRenderState: Equatable {
    case idle, rendering, ready
}

enum VideoPreset: String, CaseIterable, Hashable {
    case ugcTestimonial = "UGC testimonial"
    case productLoop = "Product loop"
    case hookTest = "Hook test"
    case unboxing = "Unboxing"
    case talkingHead = "Talking head"

    var title: String { rawValue }

    /// A few storyboards, shared across the presets that would shoot the
    /// same way.
    var shots: [VideoShot] {
        switch self {
        case .ugcTestimonial, .talkingHead: VideoShot.testimonialSet
        case .productLoop, .unboxing: VideoShot.productSet
        case .hookTest: VideoShot.hookSet
        }
    }
}

struct VideoShot: Identifiable, Hashable {
    let id = UUID()
    var image: String
    var start: Double
    var duration: Double
    var title: String
    var direction: String

    var stamp: String { timecode(start) }

    static let testimonialSet: [VideoShot] = [
        VideoShot(image: "focus", start: 0, duration: 4, title: "The hook", direction: "Straight to camera, natural light."),
        VideoShot(image: "chill", start: 4, duration: 4, title: "The problem", direction: "Holds the empty bottle, shrugs."),
        VideoShot(image: "energy", start: 8, duration: 4, title: "The product", direction: "Cracks the seal, close in."),
        VideoShot(image: "glow", start: 12, duration: 3, title: "The verdict", direction: "Takes a sip, says the line."),
    ]

    static let productSet: [VideoShot] = [
        VideoShot(image: "fun", start: 0, duration: 4, title: "The tease", direction: "Cap catches light, macro, slow."),
        VideoShot(image: "glow", start: 4, duration: 4, title: "The pop", direction: "Cap twists off close to the mic."),
        VideoShot(image: "recover", start: 8, duration: 4, title: "The pour", direction: "Over ice, slowly, window light."),
        VideoShot(image: "chill", start: 12, duration: 3, title: "The hold", direction: "Bottle turns, logo settles centre."),
    ]

    static let hookSet: [VideoShot] = [
        VideoShot(image: "energy", start: 0, duration: 3, title: "Cold open A", direction: "Bottle drops onto ice, sound first."),
        VideoShot(image: "focus", start: 3, duration: 3, title: "Cold open B", direction: "Straight to the tagline, bold type."),
        VideoShot(image: "fun", start: 6, duration: 3, title: "Cold open C", direction: "Hand reaches in, grabs it fast."),
        VideoShot(image: "recover", start: 9, duration: 4, title: "The pour", direction: "Settles into the calm shot."),
        VideoShot(image: "glow", start: 13, duration: 2, title: "The line", direction: "\"Tastes like a day off.\""),
    ]
}

// MARK: - Shot card

private struct ShotCard: View {
    let shot: VideoShot
    let width: CGFloat
    let selected: Bool
    let regenerating: Bool
    let onSelect: () -> Void
    let onRegenerate: () -> Void

    private var height: CGFloat { width * 16 / 9 }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack {
                Shot(name: shot.image)
                if regenerating {
                    Palette.ground.opacity(0.55)
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Palette.ink)
                        .rotationEffect(.degrees(regenerating ? 360 : 0))
                        .animation(.linear(duration: 0.6).repeatForever(autoreverses: false), value: regenerating)
                }
            }
            .frame(width: width, height: height)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(alignment: .topLeading) {
                Text(shot.stamp)
                    .font(.system(size: 10, weight: .semibold).monospacedDigit())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 7)
                    .frame(height: 18)
                    .background(Capsule().fill(.black.opacity(0.55)))
                    .padding(8)
            }
            .overlay(alignment: .topTrailing) {
                RegenerateButton(action: onRegenerate).padding(6)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(selected ? Palette.ink : .clear, lineWidth: 2)
            )
            Text(shot.title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Palette.ink)
                .lineLimit(1)
            Text(shot.direction)
                .font(.system(size: 11))
                .foregroundStyle(Palette.muted)
                .lineLimit(1)
        }
        .frame(width: width, alignment: .leading)
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
    }
}

private struct RegenerateButton: View {
    let action: () -> Void
    @State private var over = false

    var body: some View {
        Button(action: action) {
            Image(systemName: "arrow.clockwise")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(Circle().fill(.black.opacity(over ? 0.7 : 0.5)))
        }
        .buttonStyle(.plain)
        .help("Regenerate this shot")
        .onHover { hovering in withAnimation(Motion.quick) { over = hovering } }
    }
}

// MARK: - Voice row

private struct VoiceRow: View {
    let label: String
    let selected: Bool
    let playing: Bool
    let onSelect: () -> Void
    let onPlay: () -> Void
    @State private var over = false

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle().strokeBorder(Palette.hairline, lineWidth: 1)
                if selected {
                    Circle().fill(Palette.ink)
                    Image(systemName: "checkmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(Palette.ground)
                }
            }
            .frame(width: 16, height: 16)
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Palette.ink)
                .lineLimit(1)
            Spacer(minLength: 4)
            IconButton(symbol: playing ? "waveform" : "play.fill", help: "Preview", action: onPlay)
        }
        .padding(.horizontal, 8)
        .frame(height: 34)
        .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(selected ? Palette.wash : (over ? Palette.hover : .clear)))
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
        .onHover { hovering in withAnimation(Motion.quick) { over = hovering } }
    }
}

// MARK: - Captions switch

private struct CaptionsSwitch: View {
    let on: Bool
    let action: () -> Void
    @State private var over = false

    var body: some View {
        Button(action: action) {
            Capsule()
                .fill(on ? Palette.ink : Palette.wash)
                .frame(width: 40, height: 24)
                .overlay(alignment: .leading) {
                    Circle()
                        .fill(Palette.ground)
                        .overlay(Circle().strokeBorder(Palette.hairline, lineWidth: on ? 0 : 1))
                        .frame(width: 18, height: 18)
                        .shadow(color: .black.opacity(0.16), radius: 2, y: 1)
                        .padding(.leading, on ? 19 : 3)
                }
        }
        .buttonStyle(.plain)
        .opacity(over ? 0.85 : 1)
        .onHover { hovering in withAnimation(Motion.quick) { over = hovering } }
        .animation(Motion.quick, value: on)
    }
}
