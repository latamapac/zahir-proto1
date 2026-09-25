import SwiftUI
import AppKit

// The image studio: Higgsfield and Midjourney, but locked to one brand.
// Left, the controls that shape a run; right, the canvas where variants land,
// get compared, or get locked in. Nothing here calls out — every "generate"
// is a timer and a shuffle of the six Palmix product shots.

struct ZImageVariant: Identifiable, Hashable {
    let id = UUID()
    var image: String
    var locked = false
}

struct ZImageRun: Identifiable {
    let id = UUID()
    var prompt: String
    var style: String
    var aspectName: String
    var brandLock: Bool
    var variants: [ZImageVariant]
}

struct ImageStudio: View {
    @ObservedObject var store = ZahirStore.shared

    /// Set only by Snapshot, so a forced run doesn't get overwritten by the
    /// handoff check on appear.
    private let forcedRun: ZImageRun?
    private let forcedReference: ZReference?

    @State private var prompt: String
    @State private var brandLock: Bool
    @State private var productID: String?
    @State private var style: String
    @State private var aspectName: String
    @State private var count = 4
    @State private var run: ZImageRun?
    @State private var selected: Set<UUID>
    @State private var generating = false
    @State private var showCompare: Bool
    @State private var history: [ZImageRun]
    @State private var generateTask: Task<Void, Never>?

    /// `run`, `selected` and `reference` render a state directly, for
    /// Snapshot, without touching the shared store.
    init(run: ZImageRun? = nil, selected: Set<UUID> = [], reference: ZReference? = nil, compare: Bool = false) {
        forcedRun = run
        forcedReference = reference
        _prompt = State(initialValue: run?.prompt ?? "")
        _brandLock = State(initialValue: run?.brandLock ?? true)
        _productID = State(initialValue: nil)
        _style = State(initialValue: run?.style ?? Self.styles[0])
        _aspectName = State(initialValue: run?.aspectName ?? "Square")
        _run = State(initialValue: run)
        _selected = State(initialValue: selected)
        _showCompare = State(initialValue: compare)
        _history = State(initialValue: Self.seedHistory)
    }

    private static let styles = ["Real light", "Studio", "Flat lay", "Hands", "Night"]
    private var aspects: [ZFormat] { Array(ZFormat.all.prefix(4)) } // Story, Square, Portrait, Feed

    private var activeReference: ZReference? { forcedReference ?? store.reference }

    var body: some View {
        HStack(spacing: 0) {
            leftColumn
            Rectangle().fill(Palette.hairline).frame(width: 1)
            canvas
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.ground)
        .onAppear(perform: applyHandoff)
        .onDisappear { generateTask?.cancel() }
    }

    private func applyHandoff() {
        guard forcedRun == nil, run == nil, let handoff = store.handoff else { return }
        prompt = handoff.title
        if let image = handoff.image, store.brand.products.contains(where: { $0.image == image }) {
            productID = image
        }
    }

    // MARK: - Left: controls

    private var leftColumn: some View {
        Group {
            if Snapshot.running {
                controls
            } else {
                ScrollView(.vertical, showsIndicators: false) { controls }
            }
        }
        .frame(width: 300)
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 16) {
            promptSection
            brandLockRow
            productPicker
            stylePicker
            aspectPicker
            countPicker
            referenceSlot
            PrimaryButton(title: "Generate", symbol: "sparkle", action: generate)
                .padding(.top, 2)
        }
        .padding(18)
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text).font(.system(size: 13, weight: .medium)).foregroundStyle(Palette.muted)
    }

    private var promptSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            fieldLabel("Prompt")
            Group {
                if Snapshot.running {
                    Text(prompt.isEmpty ? "Describe the shot you want." : prompt)
                        .foregroundStyle(prompt.isEmpty ? Palette.muted : Palette.ink)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    TextField("Describe the shot you want.", text: $prompt, axis: .vertical)
                        .textFieldStyle(.plain)
                        .foregroundStyle(Palette.ink)
                        .lineLimit(3...6)
                }
            }
            .font(.system(size: 14))
            .padding(12)
            .frame(minHeight: 64, alignment: .topLeading)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Palette.wash))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Palette.hairline, lineWidth: 1))
        }
    }

    private var brandLockRow: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Brand lock")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Palette.ink)
                Text("Palette, light and rules from \(store.brand.name)")
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            StudioSwitch(on: brandLock) { withAnimation(Motion.quick) { brandLock.toggle() } }
        }
    }

    private var productPicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            fieldLabel("Product")
            if store.brand.products.isEmpty {
                Text("No products yet").font(.system(size: 12)).foregroundStyle(Palette.muted)
            } else {
                HStack(spacing: 6) {
                    ForEach(store.brand.products) { product in
                        ProductThumb(product: product, selected: product.id == productID) {
                            withAnimation(Motion.quick) { productID = productID == product.id ? nil : product.id }
                        }
                    }
                }
            }
        }
    }

    private var stylePicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            fieldLabel("Style")
            Flow(spacing: 6, line: 6) {
                ForEach(Self.styles, id: \.self) { candidate in
                    Choice(text: candidate, on: candidate == style) {
                        withAnimation(Motion.quick) { style = candidate }
                    }
                }
            }
        }
    }

    private var aspectPicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            fieldLabel("Aspect")
            HStack(spacing: 2) {
                ForEach(aspects) { format in
                    AspectOption(format: format, selected: format.name == aspectName) {
                        withAnimation(Motion.quick) { aspectName = format.name }
                    }
                }
            }
        }
    }

    private var countPicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            fieldLabel("Count")
            HStack(spacing: 8) {
                ForEach([2, 4, 8], id: \.self) { n in
                    Choice(text: "\(n)", on: n == count) { withAnimation(Motion.quick) { count = n } }
                }
            }
        }
    }

    private var referenceSlot: some View {
        VStack(alignment: .leading, spacing: 6) {
            fieldLabel("Reference")
            if let reference = activeReference {
                HStack(spacing: 10) {
                    ReferenceThumb(nsImage: reference.image)
                        .frame(width: 40, height: 40)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(reference.source)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Palette.ink)
                            .lineLimit(1)
                        Text(reference.note)
                            .font(.system(size: 11))
                            .foregroundStyle(Palette.muted)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 4)
                    IconButton(symbol: "xmark", help: "Clear reference") {
                        withAnimation(Motion.quick) { store.reference = nil }
                    }
                }
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Palette.wash))
            } else {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "viewfinder")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Palette.muted)
                        .padding(.top, 1)
                    Text("Point at anything on a page to start from it (⌘⇧E)")
                        .font(.system(size: 12))
                        .foregroundStyle(Palette.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
                        .foregroundStyle(Palette.hairline)
                )
            }
        }
    }

    // MARK: - Right: canvas

    /// No ScrollView: the grid sizes its own tiles to whatever height is
    /// left after the header and the history strip, so everything the run
    /// needs is always on screen at once.
    private var canvas: some View {
        VStack(alignment: .leading, spacing: 0) {
            canvasContent
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            if !history.isEmpty {
                historyStrip
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var canvasContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            if showCompare, let pair = compareVariants {
                CompareView(a: pair.0, b: pair.1, onKeep: keepCompare, onClose: {
                    withAnimation(Motion.quick) { showCompare = false }
                })
            } else if let run {
                runHeader(run)
                GeometryReader { geo in
                    variantGrid(run, available: geo.size)
                }
            } else {
                EmptyState(
                    symbol: "photo.on.rectangle.angled",
                    title: "Nothing generated yet",
                    line: "Write a prompt on the left and generate a first set."
                )
                .frame(maxWidth: .infinity)
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private func runHeader(_ run: ZImageRun) -> some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 8) {
                Text(run.prompt)
                    .font(.system(size: 19, weight: .semibold))
                    .tracking(-0.3)
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    if run.brandLock { Tag(text: "Brand lock", symbol: "lock.fill", strong: true) }
                    Tag(text: run.style)
                    Tag(text: run.aspectName)
                }
            }
            Spacer(minLength: 12)
            if selected.count == 2, !generating {
                Chip(text: "Compare") { withAnimation(Motion.settle) { showCompare = true } }
            }
        }
    }

    /// Two columns up to 4 variants; more than that wraps to four, so the
    /// grid is never more than two rows deep.
    private func columns(for total: Int) -> Int { total > 4 ? 4 : 2 }

    private func variantGrid(_ run: ZImageRun, available: CGSize) -> some View {
        let cols = columns(for: run.variants.count)
        let rows = Int(ceil(Double(run.variants.count) / Double(cols)))
        let spacing: CGFloat = 16
        let widthPerTile = (available.width - spacing * CGFloat(cols - 1)) / CGFloat(cols)
        let heightPerTile = (available.height - spacing * CGFloat(max(rows - 1, 0))) / CGFloat(max(rows, 1))
        let ratio = currentAspect.ratio
        // The limiting dimension: fit the tile inside whichever axis is tighter.
        let tileHeight = max(60, min(heightPerTile, widthPerTile / ratio))
        let tileSize = CGSize(width: tileHeight * ratio, height: tileHeight)

        return LazyVGrid(columns: Array(repeating: GridItem(.fixed(tileSize.width), spacing: spacing), count: cols), spacing: spacing) {
            ForEach(Array(run.variants.enumerated()), id: \.element.id) { index, variant in
                Dealt(index: index) {
                    VariantCard(
                        variant: variant,
                        size: tileSize,
                        generating: generating,
                        selected: selected.contains(variant.id),
                        onToggleSelect: { toggleSelect(variant.id) },
                        onToggleLock: { toggleLock(variant.id) },
                        onAction: { action in store.toast("\(action) started") }
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }

    private var currentAspect: ZFormat {
        aspects.first { $0.name == aspectName } ?? aspects[1]
    }

    private var historyStrip: some View {
        VStack(alignment: .leading, spacing: 10) {
            Rectangle().fill(Palette.hairline).frame(height: 1)
            HStack(spacing: 10) {
                ForEach(history.prefix(5)) { past in
                    HistoryThumb(run: past, active: past.id == run?.id) {
                        loadHistory(past)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 14)
        }
    }

    // MARK: - Actions

    private var compareVariants: (ZImageVariant, ZImageVariant)? {
        guard let run, selected.count == 2 else { return nil }
        let ids = Array(selected)
        guard let a = run.variants.first(where: { $0.id == ids[0] }),
              let b = run.variants.first(where: { $0.id == ids[1] }) else { return nil }
        return (a, b)
    }

    private func toggleSelect(_ id: UUID) {
        if selected.contains(id) {
            selected.remove(id)
        } else {
            selected.insert(id)
        }
        if selected.count != 2 { withAnimation(Motion.quick) { showCompare = false } }
    }

    private func toggleLock(_ id: UUID) {
        guard var current = run, let index = current.variants.firstIndex(where: { $0.id == id }) else { return }
        current.variants[index].locked.toggle()
        withAnimation(Motion.quick) { run = current }
    }

    private func loadHistory(_ past: ZImageRun) {
        withAnimation(Motion.settle) {
            run = past
            selected = []
            showCompare = false
            prompt = past.prompt
            style = past.style
            aspectName = past.aspectName
            brandLock = past.brandLock
        }
    }

    private func keepCompare(_ variant: ZImageVariant) {
        guard let run else { return }
        let productName = store.brand.products.first { $0.image == variant.image }?.name
        store.keep(ZAsset(.image, run.prompt, image: variant.image, product: productName, made: "Now"))
        withAnimation(Motion.settle) { showCompare = false }
    }

    private func generate() {
        guard !generating else { return }
        let text = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalPrompt = text.isEmpty ? "A bottle in the light" : text
        let n = count
        let placeholder = ZImageRun(
            prompt: finalPrompt, style: style, aspectName: aspectName, brandLock: brandLock,
            variants: (0..<n).map { _ in ZImageVariant(image: "") }
        )
        selected = []
        withAnimation(Motion.settle) {
            showCompare = false
            generating = true
            run = placeholder
        }

        generateTask?.cancel()
        generateTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_400_000_000)
            guard !Task.isCancelled else { return }
            let images = Self.images(for: n, seed: finalPrompt + style + (productID ?? ""))
            let finished = ZImageRun(
                prompt: finalPrompt, style: style, aspectName: aspectName, brandLock: brandLock,
                variants: images.map { ZImageVariant(image: $0) }
            )
            withAnimation(Motion.settle) {
                generating = false
                run = finished
                history.insert(finished, at: 0)
                if history.count > 5 { history.removeLast() }
            }
        }
    }

    private static func images(for count: Int, seed: String) -> [String] {
        let pool = ["chill", "energy", "focus", "fun", "glow", "recover"]
        let offset = abs(seed.hashValue) % pool.count
        return (0..<count).map { pool[(offset + $0) % pool.count] }
    }

    // MARK: - Seeds

    private static let seedHistory: [ZImageRun] = [
        ZImageRun(prompt: "Your 3pm, without the crash.", style: "Real light", aspectName: "Square", brandLock: true,
                   variants: ["energy", "chill", "glow", "fun"].map { ZImageVariant(image: $0) }),
        ZImageRun(prompt: "Slow is a flavour.", style: "Flat lay", aspectName: "Story", brandLock: true,
                   variants: ["chill", "focus", "recover", "energy"].map { ZImageVariant(image: $0) }),
        ZImageRun(prompt: "Hands around a cold bottle, on the beach.", style: "Hands", aspectName: "Portrait", brandLock: true,
                   variants: ["glow", "fun", "chill", "energy"].map { ZImageVariant(image: $0) }),
        ZImageRun(prompt: "Focus, alone on a quiet desk.", style: "Studio", aspectName: "Feed", brandLock: false,
                   variants: ["focus", "recover", "chill", "glow"].map { ZImageVariant(image: $0) }),
        ZImageRun(prompt: "Summer, bottled honestly.", style: "Real light", aspectName: "Square", brandLock: true,
                   variants: ["glow", "energy", "fun", "recover"].map { ZImageVariant(image: $0) }),
    ]

    /// Named states for Snapshot: each is rendered to a PNG for review.
    @MainActor static var snapshots: [(String, AnyView)] {
        var gridRun = ZImageRun(
            prompt: "Your 3pm, without the crash.", style: "Real light", aspectName: "Square", brandLock: true,
            variants: ["energy", "chill", "glow", "fun"].map { ZImageVariant(image: $0) }
        )
        gridRun.variants[0].locked = true

        let compareRun = ZImageRun(
            prompt: "Slow is a flavour.", style: "Flat lay", aspectName: "Portrait", brandLock: true,
            variants: ["chill", "glow"].map { ZImageVariant(image: $0) }
        )
        let compareSelection = Set(compareRun.variants.map(\.id))

        let referenceRun = ZImageRun(
            prompt: "Their hero ad, in our light.", style: "Real light", aspectName: "Square", brandLock: true,
            variants: images(for: 4, seed: "vitacoco-energy").map { ZImageVariant(image: $0) }
        )
        let reference = ZReference(image: Shots.image("energy"), source: "vitacoco.com", note: "Their hero ad")

        return [
            ("image-1-grid", AnyView(ImageStudio(run: gridRun).frame(width: 1180, height: 740))),
            ("image-2-compare", AnyView(ImageStudio(run: compareRun, selected: compareSelection, compare: true).frame(width: 1180, height: 740))),
            ("image-3-reference", AnyView(ImageStudio(run: referenceRun, reference: reference).frame(width: 1180, height: 740))),
        ]
    }
}

// MARK: - Small pieces

/// A capsule with a knob: ink when on, wash when off. The same shape as the
/// brand room's rule switch, local because that one is private to its file.
private struct StudioSwitch: View {
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

private struct ProductThumb: View {
    let product: ZProduct
    let selected: Bool
    let action: () -> Void
    @State private var over = false

    var body: some View {
        Button(action: action) {
            Shot(name: product.image)
                .frame(width: 34, height: 34)
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .strokeBorder(selected ? Palette.ink : Palette.hairline, lineWidth: selected ? 1.5 : 1)
                )
                .opacity(over ? 0.85 : 1)
        }
        .buttonStyle(.plain)
        .help(product.name)
        .onHover { hovering in withAnimation(Motion.quick) { over = hovering } }
    }
}

/// A tiny rectangle in the shape of the format: a Story is tall, a Feed is wide.
private struct AspectOption: View {
    let format: ZFormat
    let selected: Bool
    let action: () -> Void
    @State private var over = false

    private var size: CGSize {
        let edge: CGFloat = 24
        return format.ratio >= 1
            ? CGSize(width: edge, height: edge / format.ratio)
            : CGSize(width: edge * format.ratio, height: edge)
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(selected ? Palette.ink : Palette.faint)
                    .frame(width: size.width, height: size.height)
                    .frame(height: 26)
                Text(format.name)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(selected ? Palette.ink : Palette.muted)
            }
            .frame(width: 62, height: 52)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(over ? Palette.hover : .clear))
        }
        .buttonStyle(.plain)
        .onHover { hovering in withAnimation(Motion.quick) { over = hovering } }
    }
}

private struct ReferenceThumb: View {
    let nsImage: NSImage?

    var body: some View {
        if let nsImage {
            Image(nsImage: nsImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else {
            Palette.wash
        }
    }
}

/// A soft animated wash, not a spinner: the loading state Zahir allows itself.
private struct ShimmerFill: View {
    @State private var bright = false

    var body: some View {
        Rectangle()
            .fill(Palette.wash)
            .overlay(Rectangle().fill(Palette.hover).opacity(bright ? 1 : 0))
            .onAppear {
                guard !Snapshot.running else { return }
                withAnimation(.easeInOut(duration: 0.85).repeatForever(autoreverses: true)) {
                    bright = true
                }
            }
    }
}

private struct VariantCard: View {
    let variant: ZImageVariant
    let size: CGSize
    let generating: Bool
    let selected: Bool
    let onToggleSelect: () -> Void
    let onToggleLock: () -> Void
    let onAction: (String) -> Void
    @State private var over = false

    var body: some View {
        ZStack(alignment: .topLeading) {
            Group {
                if generating {
                    ShimmerFill()
                } else {
                    Shot(name: variant.image)
                }
            }
            .frame(width: size.width, height: size.height)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Palette.hairline, lineWidth: 1))
            .shadow(color: .black.opacity(over ? 0.1 : 0.05), radius: 18, y: 8)

            if !generating {
                HStack {
                    lockBadge
                    Spacer(minLength: 0)
                    selectBadge
                }
                .padding(10)

                if over {
                    actionRow
                        .padding(10)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                        .transition(.opacity)
                }
            }
        }
        .onHover { hovering in withAnimation(Motion.quick) { over = hovering } }
        .animation(Motion.quick, value: over)
    }

    private var lockBadge: some View {
        Button(action: onToggleLock) {
            Image(systemName: variant.locked ? "lock.fill" : "lock.open")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(variant.locked ? Palette.ground : Palette.ink)
                .frame(width: 26, height: 26)
                .background(Circle().fill(variant.locked ? Palette.ink : Palette.ground))
                .overlay(Circle().strokeBorder(Palette.hairline, lineWidth: variant.locked ? 0 : 1))
        }
        .buttonStyle(.plain)
        .opacity(variant.locked || over ? 1 : 0)
    }

    private var selectBadge: some View {
        Button(action: onToggleSelect) {
            ZStack {
                Circle().fill(selected ? Palette.ink : Palette.ground)
                Circle().strokeBorder(Palette.hairline, lineWidth: selected ? 0 : 1)
                if selected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Palette.ground)
                }
            }
            .frame(width: 24, height: 24)
        }
        .buttonStyle(.plain)
        .opacity(selected || over ? 1 : 0)
    }

    private var actionRow: some View {
        HStack(spacing: 6) {
            ForEach(["Upscale", "Vary", "Extend", "Remix"], id: \.self) { action in
                Button { onAction(action) } label: {
                    Text(action)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Palette.ink)
                        .padding(.horizontal, 9)
                        .frame(height: 24)
                        .background(Capsule().fill(Palette.ground))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct HistoryThumb: View {
    let run: ZImageRun
    let active: Bool
    let action: () -> Void
    @State private var over = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Shot(name: run.variants.first?.image)
                    .frame(width: 34, height: 34)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                Text(run.prompt)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
            }
            .padding(8)
            .frame(maxWidth: 220, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(active ? Palette.wash : (over ? Palette.hover : .clear)))
        }
        .buttonStyle(.plain)
        .onHover { hovering in withAnimation(Motion.quick) { over = hovering } }
    }
}

// MARK: - Compare

private struct CompareView: View {
    let a: ZImageVariant
    let b: ZImageVariant
    let onKeep: (ZImageVariant) -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("Compare")
                    .font(.system(size: 19, weight: .semibold))
                    .tracking(-0.3)
                    .foregroundStyle(Palette.ink)
                Spacer(minLength: 0)
                IconButton(symbol: "xmark", help: "Close compare", action: onClose)
            }
            HStack(alignment: .top, spacing: 28) {
                CompareColumn(variant: a, rate: "2.1%", label: "A", onKeep: { onKeep(a) })
                CompareColumn(variant: b, rate: "1.7%", label: "B", onKeep: { onKeep(b) })
            }
        }
    }
}

private struct CompareColumn: View {
    let variant: ZImageVariant
    let rate: String
    let label: String
    let onKeep: () -> Void
    @State private var kept = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Color.clear
                .aspectRatio(4 / 5, contentMode: .fit)
                .overlay(Shot(name: variant.image))
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(Palette.hairline, lineWidth: 1))
            Text("Predicted click rate \(rate)")
                .font(.system(size: 13).monospacedDigit())
                .foregroundStyle(Palette.muted)
            KeepChip(label: label, kept: kept) {
                onKeep()
                kept = true
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// A plain Chip that only grows a checkmark once the pick has been kept.
private struct KeepChip: View {
    let label: String
    let kept: Bool
    let action: () -> Void
    @State private var over = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if kept {
                    Image(systemName: "checkmark").font(.system(size: 11, weight: .medium))
                }
                Text(kept ? "Kept" : "Keep \(label)").font(.system(size: 13, weight: .medium))
            }
            .foregroundStyle(Palette.ink)
            .padding(.horizontal, 12)
            .frame(height: 30)
            .background(Capsule().fill(over ? Palette.hover : Palette.wash))
        }
        .buttonStyle(.plain)
        .disabled(kept)
        .onHover { hovering in withAnimation(Motion.quick) { over = hovering } }
    }
}
