import SwiftUI

// Playbooks: know-how FANDS has already proven, packaged as a chain of steps
// Figaro runs on its own, stopping at the checkpoints that need a person.
// Click one to watch it work: the steps it has done, the one it's on, and
// the ones still ahead — with what a run produces and why FANDS built it
// this way sitting beside the chain.

struct PlaybooksSurface: View {
    @ObservedObject var store = ZahirStore.shared
    @State private var selection: String?
    @State private var filter: PlaybookFilter = .all
    @State private var showRun = false

    /// `selection` opens straight to a playbook's detail, for Snapshot.
    init(selection: String? = nil) {
        _selection = State(initialValue: selection)
    }

    var body: some View {
        ZStack {
            SurfacePage(
                title: "Playbooks",
                line: selection == nil
                    ? "Know-how that works, run by Figaro. Most come from FANDS, the agency behind Zahir."
                    : nil
            ) {
                if selection == nil {
                    Choice(text: "All", on: filter == .all) { filter = .all }
                    Choice(text: "From FANDS", on: filter == .fands) { filter = .fands }
                    Choice(text: "Yours", on: filter == .yours) { filter = .yours }
                    PrimaryButton(title: "New playbook") {
                        store.toast("Tell Figaro what you do every week and it'll write it down")
                    }
                }
            } content: {
                if let id = selection, store.playbooks.contains(where: { $0.id == id }) {
                    DetailContent(
                        playbookID: id,
                        runSheetOpen: showRun,
                        onBack: { selection = nil; showRun = false },
                        onRun: { showRun = true }
                    )
                } else {
                    LibraryContent(filter: filter, onOpen: { id in selection = id })
                }
            }

            if showRun, let id = selection, let playbook = store.playbooks.first(where: { $0.id == id }) {
                RunSheet(
                    brandName: store.brand.name,
                    products: store.brand.products,
                    onCancel: { showRun = false },
                    onStart: { product, start in startRun(playbook.id, product: product, start: start) }
                )
                .transition(.opacity)
            }
        }
        .animation(Motion.settle, value: selection)
        .animation(Motion.quick, value: showRun)
    }

    private func startRun(_ id: String, product: String, start: String) {
        guard let i = store.playbooks.firstIndex(where: { $0.id == id }) else { return }
        store.playbooks[i].running = true
        store.toast("Running for \(product), starting \(start.lowercased()).")
    }

    /// Named states for Snapshot: each is rendered to a PNG for review.
    @MainActor static var snapshots: [(String, AnyView)] {
        [
            ("playbooks-1-library", AnyView(PlaybooksSurface().frame(width: 1180, height: 740))),
            ("playbooks-2-running", AnyView(PlaybooksSurface(selection: "launch").frame(width: 1180, height: 740))),
        ]
    }
}

private enum PlaybookFilter { case all, fands, yours }

// MARK: - Library

private struct LibraryContent: View {
    @ObservedObject var store = ZahirStore.shared
    let filter: PlaybookFilter
    let onOpen: (String) -> Void

    private var filtered: [ZPlaybook] {
        switch filter {
        case .all: store.playbooks
        case .fands: store.playbooks.filter { $0.from == "FANDS" }
        case .yours: store.playbooks.filter { $0.from == "You" }
        }
    }

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 20), count: 3)

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            if let running = store.playbooks.first(where: \.running) {
                RunningHero(playbook: running, action: { onOpen(running.id) })
            }
            if filtered.isEmpty {
                EmptyState(
                    symbol: "book.closed",
                    title: "No playbooks here",
                    line: "Try a different filter, or ask Figaro to write one down."
                )
            } else {
                LazyVGrid(columns: columns, alignment: .leading, spacing: 20) {
                    ForEach(Array(filtered.enumerated()), id: \.element.id) { index, playbook in
                        Dealt(index: index) {
                            PlaybookCard(playbook: playbook, action: { onOpen(playbook.id) })
                        }
                    }
                }
            }
        }
    }
}

private struct RunningHero: View {
    let playbook: ZPlaybook
    let action: () -> Void
    @State private var over = false

    private var doneCount: Int { playbook.steps.filter(\.done).count }
    private var total: Int { max(playbook.steps.count, 1) }
    private var nextCheckpoint: ZPlayStep? { playbook.steps.first { $0.checkpoint && !$0.done } }

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 18) {
                Color.clear
                    .frame(width: 84, height: 84)
                    .overlay(Shot(name: playbook.image))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Text("Running now")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Palette.ink)
                        Circle().fill(Palette.muted).frame(width: 3, height: 3)
                        Text(playbook.name)
                            .font(.system(size: 12))
                            .foregroundStyle(Palette.muted)
                    }
                    Text("Step \(min(doneCount + 1, playbook.steps.count)) of \(playbook.steps.count)")
                        .font(.system(size: 18, weight: .semibold))
                        .tracking(-0.2)
                        .foregroundStyle(Palette.ink)
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Palette.wash)
                            Capsule()
                                .fill(Palette.ink)
                                .frame(width: geo.size.width * CGFloat(doneCount) / CGFloat(total))
                        }
                    }
                    .frame(height: 4)
                    if let nextCheckpoint {
                        HStack(spacing: 6) {
                            Image(systemName: "person")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(Palette.muted)
                            Text("Next: \(nextCheckpoint.title)")
                                .font(.system(size: 12))
                                .foregroundStyle(Palette.muted)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .buttonStyle(.plain)
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Palette.ground))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(Palette.hairline, lineWidth: 1))
        .shadow(color: .black.opacity(over ? 0.1 : 0.05), radius: over ? 26 : 20, y: over ? 12 : 8)
        .onHover { hovering in withAnimation(Motion.quick) { over = hovering } }
    }
}

private struct PlaybookCard: View {
    let playbook: ZPlaybook
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Color.clear
                .frame(maxWidth: .infinity)
                .frame(height: 108)
                .overlay(Shot(name: playbook.image))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(playbook.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                Text(playbook.line)
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.muted)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 6) {
                if playbook.from == "FANDS" {
                    Tag(text: "From FANDS", symbol: "checkmark.seal")
                } else {
                    Tag(text: "Yours")
                }
                Tag(text: playbook.length)
                Tag(text: "\(playbook.steps.count) steps")
            }

            HStack(spacing: 5) {
                ForEach(Array(playbook.steps.enumerated()), id: \.offset) { _, step in
                    Image(systemName: step.tool.symbol)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(Palette.muted)
                        .frame(width: 20, height: 20)
                        .background(Circle().fill(Palette.wash))
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Palette.ground))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Palette.hairline, lineWidth: 1))
        .contentShape(Rectangle())
        .onTapGesture(perform: action)
    }
}

// MARK: - Detail

private struct DetailContent: View {
    @ObservedObject var store = ZahirStore.shared
    let playbookID: String
    let runSheetOpen: Bool
    let onBack: () -> Void
    let onRun: () -> Void

    @State private var advanceTask: Task<Void, Never>?

    private var index: Int? { store.playbooks.firstIndex { $0.id == playbookID } }

    var body: some View {
        if let i = index {
            let playbook = store.playbooks[i]
            VStack(alignment: .leading, spacing: 24) {
                header(playbook)
                HStack(alignment: .top, spacing: 40) {
                    StepChain(
                        steps: displaySteps(playbook),
                        running: playbook.running,
                        onApprove: approve,
                        onChange: change
                    )
                    .frame(width: 520, alignment: .leading)

                    VStack(alignment: .leading, spacing: 20) {
                        WhatYouGet(playbook: playbook)
                        WhyItWorks(playbook: playbook)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .onDisappear { advanceTask?.cancel() }
        } else {
            EmptyState(
                symbol: "book.closed",
                title: "Playbook not found",
                line: "It isn't in the library anymore.",
                action: ("Back to playbooks", onBack)
            )
        }
    }

    private func header(_ playbook: ZPlaybook) -> some View {
        HStack(alignment: .top, spacing: 14) {
            IconButton(symbol: "chevron.left", help: "Back to playbooks", action: onBack)
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(playbook.name)
                        .font(.system(size: 22, weight: .semibold))
                        .tracking(-0.3)
                        .foregroundStyle(Palette.ink)
                    if playbook.running {
                        Tag(text: "Running", symbol: "bolt.fill", strong: true)
                    }
                }
                Text(playbook.line)
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.muted)
                HStack(spacing: 6) {
                    if playbook.from == "FANDS" {
                        Tag(text: "From FANDS", symbol: "checkmark.seal")
                    } else {
                        Tag(text: "Yours")
                    }
                    Tag(text: playbook.length)
                    Tag(text: "\(playbook.steps.count) steps")
                }
            }
            Spacer(minLength: 12)
            if !playbook.running && !runSheetOpen {
                PrimaryButton(title: "Run for \(store.brand.name)", action: onRun)
            }
        }
    }

    private func displaySteps(_ playbook: ZPlaybook) -> [ZPlayStep] {
        Snapshot.running ? Self.settled(playbook.steps) : playbook.steps
    }

    /// For Snapshot only: Figaro finishes whatever it's mid-way through
    /// instantly, so the chain lands on the next checkpoint, waiting.
    private static func settled(_ steps: [ZPlayStep]) -> [ZPlayStep] {
        var out = steps
        var i = out.firstIndex(where: { !$0.done }) ?? out.count
        while i < out.count, !out[i].checkpoint {
            out[i].done = true
            i += 1
        }
        return out
    }

    private func approve(_ step: ZPlayStep) {
        guard let i = index, let si = store.playbooks[i].steps.firstIndex(where: { $0.id == step.id }) else { return }
        withAnimation(Motion.quick) { store.playbooks[i].steps[si].done = true }
        store.toast("Approved. Figaro's moving on to the next step.")

        let nextIndex = si + 1
        guard nextIndex < store.playbooks[i].steps.count, !store.playbooks[i].steps[nextIndex].checkpoint else { return }
        let nextStepID = store.playbooks[i].steps[nextIndex].id
        let id = playbookID

        advanceTask?.cancel()
        advanceTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            guard !Task.isCancelled else { return }
            guard let pi = ZahirStore.shared.playbooks.firstIndex(where: { $0.id == id }),
                  let ni = ZahirStore.shared.playbooks[pi].steps.firstIndex(where: { $0.id == nextStepID }) else { return }
            withAnimation(Motion.settle) {
                ZahirStore.shared.playbooks[pi].steps[ni].done = true
            }
        }
    }

    private func change(_ step: ZPlayStep) {
        store.toast("Tell Figaro what to change.")
    }
}

private struct StepChain: View {
    let steps: [ZPlayStep]
    let running: Bool
    let onApprove: (ZPlayStep) -> Void
    let onChange: (ZPlayStep) -> Void

    private var currentID: ZPlayStep.ID? { steps.first(where: { !$0.done })?.id }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(steps.enumerated()), id: \.element.id) { offset, step in
                StepRow(
                    number: offset + 1,
                    step: step,
                    isLast: offset == steps.count - 1,
                    current: step.id == currentID,
                    running: running,
                    onApprove: { onApprove(step) },
                    onChange: { onChange(step) }
                )
            }
        }
    }
}

private struct StepRow: View {
    let number: Int
    let step: ZPlayStep
    let isLast: Bool
    let current: Bool
    let running: Bool
    let onApprove: () -> Void
    let onChange: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(spacing: 0) {
                NumberBadge(number: number, filled: step.done)
                if !isLast {
                    Rectangle()
                        .fill(Palette.hairline)
                        .frame(width: 1)
                        .frame(minHeight: 26)
                        .frame(maxHeight: .infinity)
                }
            }
            .frame(width: 26)

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text(step.title)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(step.done || current ? Palette.ink : Palette.muted)
                        .fixedSize(horizontal: false, vertical: true)
                    if current && running && !step.checkpoint && !Snapshot.running {
                        ProgressView().controlSize(.mini)
                    }
                }
                Tag(text: step.tool.name, symbol: step.tool.symbol)
                if step.checkpoint {
                    CheckpointCard(waiting: current && running, onApprove: onApprove, onChange: onChange)
                }
            }
            .padding(10)
            .background(current ? AnyView(PulseWash()) : AnyView(Color.clear))
        }
        .padding(.bottom, 12)
    }
}

/// A soft animated wash, not a spinner: the current step's own quiet pulse.
private struct PulseWash: View {
    @State private var bright = false

    var body: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Palette.wash)
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Palette.hover)
                    .opacity(bright ? 1 : 0)
            )
            .onAppear {
                guard !Snapshot.running else { return }
                withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                    bright = true
                }
            }
    }
}

private struct CheckpointCard: View {
    let waiting: Bool
    let onApprove: () -> Void
    let onChange: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "person")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Palette.muted)
                Text("Waits for you")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Palette.muted)
            }
            if waiting {
                HStack(spacing: 8) {
                    Chip(text: "Approve", action: onApprove)
                    Chip(text: "Change", action: onChange)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Palette.ground))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Palette.ink.opacity(waiting ? 0.85 : 0.28), lineWidth: waiting ? 1.5 : 1)
        )
    }
}

// MARK: - Right side: what you get, why it works

private struct WhatYouGet: View {
    let playbook: ZPlaybook

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHead(title: "What you get")
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(Extras.outputs(for: playbook.id).enumerated()), id: \.offset) { index, output in
                    VStack(alignment: .leading, spacing: 0) {
                        if index > 0 { Rectangle().fill(Palette.hairline).frame(height: 1) }
                        OutputRow(output: output).padding(.vertical, 10)
                    }
                }
            }
            .zCard(radius: 16, padding: 14)
        }
    }
}

private struct OutputRow: View {
    let output: Extras.Output

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                if let image = output.image { Shot(name: image) } else { Palette.wash }
            }
            .frame(width: 40, height: 40)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            Text(output.title)
                .font(.system(size: 13))
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct WhyItWorks: View {
    let playbook: ZPlaybook

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHead(title: "Why it works")
            Text(Extras.why(for: playbook.id))
                .font(.system(size: 13))
                .foregroundStyle(Palette.muted)
                .fixedSize(horizontal: false, vertical: true)
                .zCard(radius: 16, padding: 16)
        }
    }
}

/// What a playbook produces and why FANDS built it this way: not part of
/// the shared store, since it's colour rather than data Figaro would act on.
private enum Extras {
    struct Output { let image: String?; let title: String }

    static func outputs(for id: String) -> [Output] {
        switch id {
        case "launch":
            [Output(image: "glow", title: "A 15-second TikTok for launch day"),
             Output(image: "energy", title: "Three ads, sized for every channel"),
             Output(image: nil, title: "A launch week schedule, ready to go")]
        case "weekly":
            [Output(image: "chill", title: "Five posts, written in your voice"),
             Output(image: nil, title: "A plan for the week, before Monday's coffee")]
        case "ugc":
            [Output(image: "fun", title: "Six scripts, ready to shoot"),
             Output(image: "fun", title: "Six clips, cut tight")]
        case "beat":
            [Output(image: "recover", title: "A plain read on what they're missing"),
             Output(image: "energy", title: "Three ads that take the gap")]
        case "holiday":
            [Output(image: "recover", title: "Countdown posts for the week before"),
             Output(image: nil, title: "The last-chance email")]
        default:
            []
        }
    }

    static func why(for id: String) -> String {
        switch id {
        case "launch":
            "Launches that show the product in someone's hand in the first second get twice the saves. Ads that go out the same week as the launch post outperform ones that wait."
        case "weekly":
            "Brands that post on a fixed day build an audience that checks in. Five posts a week is enough to stay visible without running out of things to say."
        case "ugc":
            "People trust a stranger's phone camera more than a studio shoot. Six short clips give enough variety to find the one that travels."
        case "beat":
            "Most competitors leave one moment of the day untouched. Naming it plainly, once, beats trying to out-shout them everywhere."
        case "holiday":
            "A countdown gives people a reason to come back before they buy. The last-chance email does more of the work than the offer itself."
        default:
            "FANDS has run this enough times to know what works."
        }
    }
}

// MARK: - Run sheet

private struct RunSheet: View {
    let brandName: String
    let products: [ZProduct]
    let onCancel: () -> Void
    let onStart: (String, String) -> Void

    private static let starts = ["Today", "Next Monday", "In two weeks"]

    @State private var product: String
    @State private var start = "Next Monday"

    init(brandName: String, products: [ZProduct], onCancel: @escaping () -> Void, onStart: @escaping (String, String) -> Void) {
        self.brandName = brandName
        self.products = products
        self.onCancel = onCancel
        self.onStart = onStart
        _product = State(initialValue: products.first?.name ?? "")
    }

    var body: some View {
        ZStack {
            Rectangle()
                .fill(Palette.ink.opacity(0.18))
                .onTapGesture(perform: onCancel)

            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Run for \(brandName)")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Palette.ink)
                    Text("Pick a product and when it starts.")
                        .font(.system(size: 13))
                        .foregroundStyle(Palette.muted)
                }
                VStack(alignment: .leading, spacing: 10) {
                    Text("Product").font(.system(size: 12, weight: .medium)).foregroundStyle(Palette.muted)
                    Flow(spacing: 8, line: 8) {
                        ForEach(products) { item in
                            Choice(text: item.name, on: item.name == product) { product = item.name }
                        }
                    }
                }
                VStack(alignment: .leading, spacing: 10) {
                    Text("Starts").font(.system(size: 12, weight: .medium)).foregroundStyle(Palette.muted)
                    Flow(spacing: 8, line: 8) {
                        ForEach(Self.starts, id: \.self) { option in
                            Choice(text: option, on: option == start) { start = option }
                        }
                    }
                }
                HStack(spacing: 10) {
                    PrimaryButton(title: "Start the playbook") { onStart(product, start) }
                    Chip(text: "Cancel", action: onCancel)
                }
            }
            .padding(24)
            .frame(width: 420, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 26, style: .continuous).fill(Palette.ground))
            .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).strokeBorder(Palette.hairline, lineWidth: 1))
            .shadow(color: .black.opacity(0.18), radius: 44, y: 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
