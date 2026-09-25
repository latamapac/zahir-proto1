import SwiftUI

// Figaro's thread: not a chat log, a table where Figaro deals cards. Your
// words sit as plain bubbles; Figaro's turns carry the tools it reached for
// and the answer itself — the same AnswerView the pill shows, scaled to fit
// a column instead of the whole page.
struct FigaroThread: View {
    @ObservedObject var store = ZahirStore.shared

    /// For Snapshot: pin a specific thread, or force the blank "new
    /// conversation" start state, without touching the shared store.
    var pin: UUID? = nil
    var empty = false

    init(pin: UUID? = nil, empty: Bool = false) {
        self.pin = pin
        self.empty = empty
    }

    @State private var draft = ""
    @State private var showTools = false
    @State private var sendOver = false
    @State private var working = false
    @State private var workingSteps: [Step] = []
    @State private var workingDone = 0
    @State private var hoveredMemoryID: ZMemory.ID?
    @State private var sendTask: Task<Void, Never>?

    private var activeThreadID: UUID? {
        if empty { return nil }
        if let pin { return (store.threads.first { $0.id == pin } ?? store.thread)?.id }
        return store.thread?.id
    }

    private var activeMessages: [ZMessage] {
        if empty { return [] }
        if let pin { return (store.threads.first { $0.id == pin } ?? store.thread)?.messages ?? [] }
        return store.thread?.messages ?? []
    }

    var body: some View {
        HStack(spacing: 0) {
            threadList
                .frame(width: 240)
                .frame(maxHeight: .infinity, alignment: .top)
            Rectangle().fill(Palette.hairline).frame(width: 1)
            conversation
                .frame(maxWidth: .infinity)
            Rectangle().fill(Palette.hairline).frame(width: 1)
            memoryColumn
                .frame(width: 280)
                .frame(maxHeight: .infinity, alignment: .top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.ground)
        .onDisappear { sendTask?.cancel() }
    }

    // MARK: - Left: threads

    private var threadList: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                FigaroMark()
                Text("Figaro")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Palette.ink)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 14)

            NewConversationRow { store.newThread() }
                .padding(.horizontal, 12)
                .padding(.bottom, 10)

            Group {
                if Snapshot.running {
                    threadRows
                } else {
                    ScrollView(.vertical, showsIndicators: false) { threadRows }
                }
            }
        }
    }

    private var threadRows: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(store.threads) { t in
                ThreadRow(thread: t, selected: t.id == activeThreadID) {
                    store.threadID = t.id
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 16)
    }

    // MARK: - Centre: conversation

    private var conversation: some View {
        VStack(spacing: 0) {
            Group {
                if Snapshot.running {
                    messageStack
                } else {
                    ScrollViewReader { proxy in
                        ScrollView(.vertical, showsIndicators: false) { messageStack }
                            .onChange(of: activeMessages.count) { _, _ in scrollToEnd(proxy) }
                            .onChange(of: working) { _, _ in scrollToEnd(proxy) }
                            .onAppear { scrollToEnd(proxy, animated: false) }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            composer
                .padding(.horizontal, 24)
                .padding(.top, 10)
                .padding(.bottom, 22)
        }
    }

    private var messageStack: some View {
        VStack(alignment: .leading, spacing: 22) {
            let messages = activeMessages
            if messages.isEmpty && !working {
                startState
            } else {
                ForEach(messages) { message in
                    MessageRow(
                        message: message,
                        onKeep: { keep(message) },
                        onOpenStudio: { if let answer = message.answer { Studio.open(answer) } },
                        onAgain: { again(message) }
                    )
                }
                if working {
                    workingRow
                }
            }
            Color.clear.frame(height: 1).id("bottom")
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .top)
    }

    private var startState: some View {
        VStack(spacing: 16) {
            EmptyState(
                symbol: "sparkle",
                title: "Ask Figaro for anything",
                line: "An ad, a script, a read on a competitor, a post for next week."
            )
            Flow(spacing: 6, line: 6) {
                ForEach(Place.home.intents, id: \.self) { intent in
                    Chip(text: intent.title) { send(intent.title) }
                }
            }
            .frame(maxWidth: 440)
        }
        .padding(.top, 24)
        .frame(maxWidth: .infinity)
    }

    private var workingRow: some View {
        HStack(alignment: .top, spacing: 10) {
            FigaroMark()
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(workingSteps.enumerated()), id: \.offset) { index, step in
                    HStack(spacing: 8) {
                        ZStack {
                            Circle().strokeBorder(Palette.hairline, lineWidth: 1)
                            if index < workingDone {
                                Circle().fill(Palette.ink)
                                Image(systemName: "checkmark")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundStyle(Palette.ground)
                            } else if index == workingDone, !Snapshot.running {
                                ProgressView().controlSize(.mini)
                            }
                        }
                        .frame(width: 16, height: 16)
                        Text(step.text)
                            .font(.system(size: 13))
                            .foregroundStyle(index <= workingDone ? Palette.ink : Palette.faint)
                    }
                }
            }
        }
    }

    private func scrollToEnd(_ proxy: ScrollViewProxy, animated: Bool = true) {
        if animated {
            withAnimation(Motion.settle) { proxy.scrollTo("bottom", anchor: .bottom) }
        } else {
            proxy.scrollTo("bottom", anchor: .bottom)
        }
    }

    // MARK: - Composer

    private var composer: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                promptField
                sendButton
            }
            HStack(spacing: 8) {
                AttachChip(symbol: "doc.text", text: "This page") { store.toast("Added this page") }
                AttachChip(symbol: "square.stack", text: "From library") { store.toast("Pick from the library") }
                AttachChip(symbol: "paperclip", text: "A file") { store.toast("Pick a file") }
                Spacer(minLength: 0)
                Chip(text: "Tools") { withAnimation(Motion.quick) { showTools.toggle() } }
            }
            if showTools {
                toolPicker
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .zCard(radius: 20)
        .animation(Motion.quick, value: showTools)
    }

    private var promptField: some View {
        Group {
            if Snapshot.running {
                Text(draft.isEmpty ? "Tell Figaro what you need" : draft)
                    .foregroundStyle(draft.isEmpty ? Palette.muted : Palette.ink)
            } else {
                TextField("Tell Figaro what you need", text: $draft, axis: .vertical)
                    .textFieldStyle(.plain)
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1...4)
                    .onSubmit { send() }
            }
        }
        .font(.system(size: 15))
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var sendButton: some View {
        Button { send() } label: {
            Image(systemName: "arrow.up")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Palette.ground)
                .frame(width: 34, height: 34)
                .background(Circle().fill(Palette.ink.opacity(sendOver ? 0.86 : 1)))
        }
        .buttonStyle(.plain)
        .onHover { hovering in withAnimation(Motion.quick) { sendOver = hovering } }
    }

    private var toolPicker: some View {
        Flow(spacing: 6, line: 6) {
            ForEach(Tool.allCases, id: \.self) { tool in
                Choice(text: tool.name, on: false, symbol: tool.symbol) {
                    draft = tool.command + " "
                    withAnimation(Motion.quick) { showTools = false }
                }
            }
        }
    }

    // MARK: - Right: memory

    private var memoryColumn: some View {
        Group {
            if Snapshot.running {
                memoryContent
            } else {
                ScrollView(.vertical, showsIndicators: false) { memoryContent }
            }
        }
    }

    private var memoryContent: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 4) {
                Text("What Figaro remembers")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(store.memories) { memory in
                        MemoryRow(
                            memory: memory,
                            hovered: hoveredMemoryID == memory.id,
                            onHover: { hovering in
                                hoveredMemoryID = hovering ? memory.id : (hoveredMemoryID == memory.id ? nil : hoveredMemoryID)
                            },
                            forget: { forget(memory) }
                        )
                    }
                }
            }

            Rectangle().fill(Palette.hairline).frame(height: 1)

            VStack(alignment: .leading, spacing: 12) {
                Text("Working on")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                brandCard
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(store.assets.prefix(3)) { asset in
                        AssetRow(asset: asset)
                    }
                }
            }
        }
        .padding(20)
    }

    private var brandCard: some View {
        HStack(spacing: 10) {
            Avatar(letter: store.brand.letter, size: 34)
            VStack(alignment: .leading, spacing: 2) {
                Text(store.brand.name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                Text(store.brand.promise)
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Palette.wash))
    }

    private func forget(_ memory: ZMemory) {
        guard let index = store.memories.firstIndex(where: { $0.id == memory.id }) else { return }
        store.memories.remove(at: index)
        store.toast("Forgotten", symbol: "xmark", undo: {
            guard !ZahirStore.shared.memories.contains(where: { $0.id == memory.id }) else { return }
            ZahirStore.shared.memories.insert(memory, at: min(index, ZahirStore.shared.memories.count))
        })
    }

    // MARK: - Sending

    private func send(_ text: String? = nil) {
        let raw = (text ?? draft).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty, !working else { return }
        if text == nil { draft = "" }
        showTools = false

        var content = raw
        var kind = Kind.guess(from: raw)
        if let tool = Tool.picked(by: raw) {
            let rest = raw.dropFirst(tool.command.count).trimmingCharacters(in: .whitespaces)
            content = rest.isEmpty ? tool.fallback : rest
            kind = tool.kind
        }

        store.say(ZMessage(fromFigaro: false, text: content, time: "Now"))

        let steps = Step.plan(kind)
        workingSteps = steps
        workingDone = 0
        withAnimation(Motion.settle) { working = true }

        sendTask?.cancel()
        sendTask = Task { @MainActor in
            for _ in steps {
                try? await Task.sleep(nanoseconds: 620_000_000)
                guard !Task.isCancelled else { return }
                withAnimation(Motion.quick) { workingDone += 1 }
            }
            try? await Task.sleep(nanoseconds: 200_000_000)
            guard !Task.isCancelled else { return }

            var toolsUsed: [Tool] = []
            for step in steps where !toolsUsed.contains(step.tool) { toolsUsed.append(step.tool) }
            let answer = Answer.make(kind, ask: content, place: .home)

            withAnimation(Motion.settle) {
                working = false
                store.say(ZMessage(fromFigaro: true, text: answer.heading, answer: answer, tools: toolsUsed, time: "Now"))
            }
        }
    }

    private func keep(_ message: ZMessage) {
        guard let answer = message.answer else { return }
        store.keep(Self.asset(for: answer))
    }

    private func again(_ message: ZMessage) {
        guard let answer = message.answer else { return }
        send(Kind.homeAsk[answer.kind] ?? message.text)
    }

    private static func asset(for answer: Answer) -> ZAsset {
        let card = answer.cards.first
        switch answer.kind {
        case .concepts: return ZAsset(.image, card?.title ?? answer.heading, image: card?.image, made: "Now")
        case .storyboard: return ZAsset(.video, answer.heading, image: card?.image, made: "Now")
        case .read: return ZAsset(.read, answer.heading, made: "Now")
        case .post: return ZAsset(.post, card?.title ?? answer.heading, image: card?.image, made: "Now")
        }
    }

    /// Named states for Snapshot: each is rendered to a PNG for review.
    @MainActor static var snapshots: [(String, AnyView)] {
        let glowID = ZahirStore.seedThreads.first?.id
        return [
            ("thread-1-glow", AnyView(FigaroThread(pin: glowID).frame(width: 1180, height: 740))),
            ("thread-2-new", AnyView(FigaroThread(empty: true).frame(width: 1180, height: 740))),
        ]
    }
}

// MARK: - Rows

private struct NewConversationRow: View {
    let action: () -> Void
    @State private var over = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 12, weight: .semibold))
                Text("New conversation")
                    .font(.system(size: 13, weight: .medium))
            }
            .foregroundStyle(Palette.ink)
            .padding(.horizontal, 12)
            .frame(height: 32)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(over ? Palette.hover : Palette.wash))
        }
        .buttonStyle(.plain)
        .onHover { hovering in withAnimation(Motion.quick) { over = hovering } }
    }
}

private struct ThreadRow: View {
    let thread: ZThread
    let selected: Bool
    let action: () -> Void
    @State private var over = false

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 2) {
                Text(thread.title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                Text(thread.updated)
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.muted)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(selected ? Palette.wash : (over ? Palette.hover : .clear)))
        }
        .buttonStyle(.plain)
        .onHover { hovering in withAnimation(Motion.quick) { over = hovering } }
    }
}

private struct AttachChip: View {
    let symbol: String
    let text: String
    let action: () -> Void
    @State private var over = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: symbol).font(.system(size: 11, weight: .medium))
                Text(text).font(.system(size: 12, weight: .medium))
            }
            .foregroundStyle(Palette.ink)
            .padding(.horizontal, 10)
            .frame(height: 26)
            .background(Capsule().fill(over ? Palette.hover : Palette.wash))
        }
        .buttonStyle(.plain)
        .onHover { hovering in withAnimation(Motion.quick) { over = hovering } }
    }
}

private struct MemoryRow: View {
    let memory: ZMemory
    let hovered: Bool
    let onHover: (Bool) -> Void
    let forget: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(memory.text)
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text(memory.source)
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.muted)
            }
            Spacer(minLength: 4)
            if hovered {
                Chip(text: "Forget", action: forget)
            }
        }
        .padding(.vertical, 9)
        .onHover(perform: onHover)
    }
}

private struct AssetRow: View {
    let asset: ZAsset
    @State private var over = false

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                if asset.image != nil {
                    Shot(name: asset.image)
                } else {
                    Palette.wash
                    Image(systemName: asset.kind.symbol)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Palette.muted)
                }
            }
            .frame(width: 40, height: 40)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 1) {
                Text(asset.title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                Text(asset.made)
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.muted)
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(over ? Palette.hover : .clear))
        .onHover { hovering in withAnimation(Motion.quick) { over = hovering } }
    }
}

// MARK: - A turn

private struct MessageRow: View {
    let message: ZMessage
    let onKeep: () -> Void
    let onOpenStudio: () -> Void
    let onAgain: () -> Void

    var body: some View {
        if message.fromFigaro {
            figaroTurn
        } else {
            userTurn
        }
    }

    private var userTurn: some View {
        HStack {
            Spacer(minLength: 60)
            VStack(alignment: .trailing, spacing: 4) {
                Text(message.text)
                    .font(.system(size: 14))
                    .foregroundStyle(Palette.ink)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Palette.wash))
                if !message.time.isEmpty {
                    Text(message.time).font(.system(size: 11)).foregroundStyle(Palette.muted)
                }
            }
        }
    }

    private var figaroTurn: some View {
        HStack(alignment: .top, spacing: 10) {
            FigaroMark()
            VStack(alignment: .leading, spacing: 12) {
                Text(message.text)
                    .font(.system(size: 15))
                    .foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)

                if !message.tools.isEmpty {
                    Flow(spacing: 6, line: 6) {
                        ForEach(message.tools, id: \.self) { tool in
                            Tag(text: tool.name, symbol: tool.symbol)
                        }
                    }
                }

                if let answer = message.answer {
                    ScaledAnswer(answer: answer)
                }

                HStack(spacing: 8) {
                    if message.answer != nil {
                        Chip(text: "Keep", action: onKeep)
                        Chip(text: "Open in studio", action: onOpenStudio)
                        Chip(text: "Again", action: onAgain)
                    }
                    if !message.time.isEmpty {
                        Text(message.time).font(.system(size: 11)).foregroundStyle(Palette.muted)
                    }
                }
            }
        }
    }
}

/// AnswerView is sized for the whole page; here it is scaled down to whatever
/// width the thread column has to give it, keeping its top-left corner put.
private struct ScaledAnswer: View {
    let answer: Answer

    private var natural: CGSize {
        switch answer.kind {
        case .concepts: CGSize(width: 812, height: 520)
        case .storyboard: CGSize(width: 576, height: 420)
        case .read: CGSize(width: 620, height: 500)
        case .post: CGSize(width: 520, height: 580)
        }
    }

    var body: some View {
        GeometryReader { geo in
            let scale = min(1, max(0.001, geo.size.width) / natural.width)
            AnswerView(answer: answer)
                .frame(width: natural.width, height: natural.height, alignment: .topLeading)
                .scaleEffect(scale, anchor: .topLeading)
                .frame(width: natural.width * scale, height: natural.height * scale, alignment: .topLeading)
        }
        .frame(height: natural.height)
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}
