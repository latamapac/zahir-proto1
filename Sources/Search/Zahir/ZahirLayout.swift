import SwiftUI

// The Canva-lite: one ad, drawn once, true to whatever size it has to be.
// AdComposition is the whole idea — photo, headline, a button, a wordmark —
// laid out by the format's own shape rather than stretched to fit; the studio
// around it just picks the inputs and shows every size at once.

// MARK: - Composition

/// How the text sits on the photo.
enum AdVariant: String, CaseIterable, Identifiable, Hashable {
    case centered = "Centered"
    case bottomBand = "Bottom band"
    case split = "Split"

    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .centered: "align.horizontal.center"
        case .bottomBand: "rectangle.bottomthird.inset.filled"
        case .split: "rectangle.split.2x1"
        }
    }
}

private func clamp(_ value: CGFloat, _ low: CGFloat, _ high: CGFloat) -> CGFloat {
    min(max(value, low), high)
}

private extension ZSwatch {
    /// Rough perceived brightness, so a panel or a button can pick its own
    /// light and dark ends from whatever palette a brand actually has.
    var luminance: Double {
        let clean = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let v = UInt64(clean, radix: 16) ?? 0
        let r = Double((v >> 16) & 0xFF), g = Double((v >> 8) & 0xFF), b = Double(v & 0xFF)
        return 0.299 * r + 0.587 * g + 0.114 * b
    }
}

private extension ZBrand {
    var darkestSwatch: ZSwatch { palette.min { $0.luminance < $1.luminance } ?? ZSwatch(name: "Ink", hex: "1B1A17") }
    var lightestSwatch: ZSwatch { palette.max { $0.luminance < $1.luminance } ?? ZSwatch(name: "Coconut", hex: "FBF8F2") }
}

/// One ad, at one size: a photo, a headline, a button, a wordmark. Every
/// input is explicit, so the same composition draws identically in the big
/// master and in a 140pt-tall thumbnail — the size is the only thing that
/// changes.
struct AdComposition: View {
    let image: String
    let headline: String
    let cta: String
    let brandName: String
    let variant: AdVariant
    let format: ZFormat
    var headlineColor: Color = Palette.ink
    var inkText: Color = Palette.ink
    var coconutFill: Color = Palette.ground
    /// A layout that hasn't been nudged to fit yet runs its headline larger
    /// than it should — the "Headline cropped" state in the format grid.
    var headlineBoost: CGFloat = 1
    var onTapHeadline: (() -> Void)? = nil

    private var isTiny: Bool { format.width <= 320 }
    private var isLandscape: Bool { format.ratio >= 1.35 }

    var body: some View {
        GeometryReader { geo in
            let short = min(geo.size.width, geo.size.height)
            let unit = short / 100
            content(unit: unit, size: geo.size)
                .frame(width: geo.size.width, height: geo.size.height)
                .clipped()
        }
    }

    @ViewBuilder
    private func content(unit: CGFloat, size: CGSize) -> some View {
        switch variant {
        case .centered:
            ZStack {
                Shot(name: image).frame(width: size.width, height: size.height)
                centeredOverlay(unit: unit, size: size)
            }
        case .bottomBand:
            ZStack {
                Shot(name: image).frame(width: size.width, height: size.height)
                bottomBandOverlay(unit: unit, size: size)
            }
        case .split:
            splitContent(unit: unit, size: size)
        }
    }

    // MARK: Centered — text block floats over the photo, on a soft scrim.

    private func centeredOverlay(unit: CGFloat, size: CGSize) -> some View {
        let maxWidth = isLandscape ? size.width * 0.5 : size.width * 0.8
        // The wordmark is its own ZStack child, pinned to the canvas corner by
        // the stack's own alignment — never nested inside the text block's
        // padding, so it can't drift over the photo's subject.
        return ZStack(alignment: .bottomLeading) {
            VStack(alignment: isLandscape ? .leading : .center, spacing: unit * 2) {
                headlineText(unit: unit, color: headlineColor, maxWidth: maxWidth, lines: isTiny ? 2 : 3, align: isLandscape ? .leading : .center)
                if !isTiny { ctaCapsule(unit: unit) }
            }
            .padding(unit * 2.6)
            .background(RoundedRectangle(cornerRadius: unit * 1.6, style: .continuous).fill(Color.black.opacity(0.3)))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: isLandscape ? .leading : .center)
            .padding(.leading, isLandscape ? size.width * 0.07 : 0)

            wordmarkText(unit: unit, color: coconutFill)
                .padding(unit * 2.2)
        }
        .frame(width: size.width, height: size.height)
    }

    // MARK: Bottom band — a solid strip; landscape lays it out sideways
    // rather than stacking, since a wide-short frame has no room to stack.

    private func bottomBandOverlay(unit: CGFloat, size: CGSize) -> some View {
        let bandHeight = isLandscape ? size.height * 0.42 : size.height * 0.32
        return VStack(spacing: 0) {
            Spacer(minLength: 0)
            Group {
                if isLandscape {
                    HStack(alignment: .center, spacing: unit * 2.4) {
                        VStack(alignment: .leading, spacing: unit) {
                            wordmarkText(unit: unit, color: inkText.opacity(0.55))
                            headlineText(unit: unit, color: inkText, maxWidth: size.width * 0.48, lines: 2, align: .leading)
                        }
                        Spacer(minLength: 0)
                        if !isTiny { ctaCapsule(unit: unit) }
                    }
                } else {
                    VStack(alignment: .leading, spacing: unit * 1.1) {
                        wordmarkText(unit: unit, color: inkText.opacity(0.55))
                        headlineText(unit: unit, color: inkText, maxWidth: size.width * 0.86, lines: isTiny ? 2 : 3, align: .leading)
                        if !isTiny { ctaCapsule(unit: unit) }
                    }
                }
            }
            .padding(.horizontal, unit * 3)
            .frame(width: size.width, height: bandHeight, alignment: isLandscape ? .center : .bottomLeading)
            .padding(.vertical, unit * 2)
            .background(coconutFill)
        }
    }

    // MARK: Split — a solid panel beside the photo; sideways in landscape,
    // stacked otherwise, which is what "moving the headline" means here.

    private func splitContent(unit: CGFloat, size: CGSize) -> some View {
        Group {
            if isLandscape {
                HStack(spacing: 0) {
                    Shot(name: image).frame(width: size.width * 0.56, height: size.height).clipped()
                    splitPanel(unit: unit, width: size.width * 0.44, height: size.height)
                }
            } else {
                VStack(spacing: 0) {
                    Shot(name: image).frame(width: size.width, height: size.height * 0.6).clipped()
                    splitPanel(unit: unit, width: size.width, height: size.height * 0.4)
                }
            }
        }
        .overlay(alignment: .bottomLeading) {
            if isLandscape {
                wordmarkText(unit: unit, color: coconutFill).padding(unit * 1.8)
            }
        }
    }

    private func splitPanel(unit: CGFloat, width: CGFloat, height: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: unit * 1.6) {
            if !isLandscape { wordmarkText(unit: unit, color: inkText.opacity(0.55)) }
            Spacer(minLength: 0)
            headlineText(unit: unit, color: inkText, maxWidth: width - unit * 5, lines: isTiny ? 2 : 4, align: .leading)
            if !isTiny { ctaCapsule(unit: unit) }
        }
        .padding(unit * 2.6)
        .frame(width: width, height: height, alignment: .leading)
        .background(coconutFill)
    }

    // MARK: Pieces every variant shares

    private func headlineText(unit: CGFloat, color: Color, maxWidth: CGFloat, lines: Int, align: TextAlignment) -> some View {
        Text(headline)
            .font(.system(size: clamp(unit * 6.4 * headlineBoost, 8, 44), weight: .semibold))
            .foregroundStyle(color)
            .multilineTextAlignment(align)
            .lineLimit(lines)
            .lineSpacing(unit * 0.5)
            .frame(maxWidth: maxWidth, alignment: align == .center ? .center : .leading)
            .contentShape(Rectangle())
            .onTapGesture { onTapHeadline?() }
    }

    private func ctaCapsule(unit: CGFloat) -> some View {
        Text(cta)
            .font(.system(size: clamp(unit * 2.7, 7, 15), weight: .semibold))
            .foregroundStyle(inkText)
            .padding(.horizontal, clamp(unit * 3.2, 8, 20))
            .frame(height: clamp(unit * 6.4, 16, 34))
            .background(Capsule().fill(coconutFill))
    }

    private func wordmarkText(unit: CGFloat, color: Color) -> some View {
        Text(brandName)
            .font(.system(size: clamp(unit * 2.3, 7, 13), weight: .semibold, design: .serif))
            .foregroundStyle(color)
            .shadow(color: .black.opacity(0.22), radius: 2, y: 1)
    }
}

// MARK: - Studio

/// The size picker: one composition, checked against every channel at once.
struct LayoutStudio: View {
    @ObservedObject var store = ZahirStore.shared

    @State private var image: String
    @State private var headline: String
    @State private var cta: String
    @State private var variant: AdVariant
    @State private var safeZones: Bool
    @State private var headlineColor: Color?
    @State private var masterFormat: ZFormat = ZFormat.all.first { $0.name == "Story" } ?? ZFormat.all[0]
    @State private var warningFixed = false
    @FocusState private var headlineFocused: Bool

    /// For Snapshot: preset the studio's local state without touching the
    /// shared store, the way the other studios pin a brand or a thread. `cta`
    /// defaults to "Try <product>" for whichever image is picked, the same
    /// rule the image grid applies when someone swaps the picture by hand.
    init(image: String = "energy", headline: String = "Your 3pm, without the crash.",
         cta: String? = nil, variant: AdVariant = .centered, safeZones: Bool = false) {
        _image = State(initialValue: image)
        _headline = State(initialValue: headline)
        let product = ZahirStore.palmix.products.first { $0.image == image }?.name
        _cta = State(initialValue: cta ?? product.map { "Try \($0)" } ?? "Try Energy")
        _variant = State(initialValue: variant)
        _safeZones = State(initialValue: safeZones)
    }

    private var brand: ZBrand { store.brand }
    /// The Centered variant sets its headline on a dark scrim, so unless the
    /// person has picked their own swatch, default to the brand's lightest
    /// one rather than its ink — the dark end would vanish into the scrim.
    private var headlineTint: Color { headlineColor ?? brand.lightestSwatch.color }
    private var warningFormat: ZFormat? { ZFormat.all.first { $0.name == "LinkedIn" } }

    var body: some View {
        HStack(spacing: 0) {
            toolsColumn
                .frame(width: 260)
                .frame(maxHeight: .infinity, alignment: .top)
            Rectangle().fill(Palette.hairline).frame(width: 1)
            masterColumn
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            Rectangle().fill(Palette.hairline).frame(width: 1)
            formatsColumn
                .frame(width: 340)
                .frame(maxHeight: .infinity, alignment: .top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.ground)
    }

    // MARK: Left — tools

    private var toolsColumn: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "rectangle.3.group")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                Text("Layout")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Palette.ink)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 16)

            Group {
                if Snapshot.running {
                    toolsContent
                } else {
                    ScrollView(.vertical, showsIndicators: false) { toolsContent }
                }
            }
        }
    }

    private var toolsContent: some View {
        VStack(alignment: .leading, spacing: 26) {
            toolSection("Image") { imageGrid }
            toolSection("Headline") { headlineField }
            toolSection("Button") { ctaField }
            toolSection("Layout") {
                Flow(spacing: 6, line: 6) {
                    ForEach(AdVariant.allCases) { option in
                        Choice(text: option.rawValue, on: option == variant, symbol: option.symbol) {
                            withAnimation(Motion.settle) { variant = option }
                        }
                    }
                }
            }
            toolSection("Safe zones") { safeZoneRow }
            toolSection("Headline colour") { swatchRow }
        }
        .padding(20)
        .padding(.bottom, 20)
    }

    private func toolSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.system(size: 13, weight: .semibold)).foregroundStyle(Palette.ink)
            content()
        }
    }

    /// A plain row-by-row grid rather than LazyVGrid: a lazy grid wants a
    /// ScrollView above it to know its own height, and this column drops the
    /// ScrollView while Snapshot is running — a lazy grid there can collapse
    /// to nothing and take the rest of the column's layout with it. Six
    /// products is nothing to be lazy about anyway.
    private var imageGrid: some View {
        let perRow = 3
        let rows = stride(from: 0, to: brand.products.count, by: perRow).map { start in
            Array(brand.products[start..<min(start + perRow, brand.products.count)])
        }
        return VStack(spacing: 8) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: 8) {
                    ForEach(row) { product in imageThumb(product) }
                    if row.count < perRow {
                        ForEach(0..<(perRow - row.count), id: \.self) { _ in Color.clear }
                    }
                }
            }
        }
    }

    private func imageThumb(_ product: ZProduct) -> some View {
        let selected = product.image == image
        return Button {
            withAnimation(Motion.quick) {
                image = product.image
                cta = "Try \(product.name)"
            }
        } label: {
            Color.clear
                .aspectRatio(1, contentMode: .fit)
                .overlay(Shot(name: product.image))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(selected ? Palette.ink : Palette.hairline, lineWidth: selected ? 2 : 1)
                )
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }

    private var headlineField: some View {
        Group {
            if Snapshot.running {
                Text(headline).foregroundStyle(Palette.ink)
            } else {
                TextField("Headline", text: $headline, axis: .vertical)
                    .textFieldStyle(.plain)
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1...3)
                    .focused($headlineFocused)
            }
        }
        .font(.system(size: 13))
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Palette.wash))
    }

    private var ctaField: some View {
        Group {
            if Snapshot.running {
                Text(cta).foregroundStyle(Palette.ink)
            } else {
                TextField("Button", text: $cta)
                    .textFieldStyle(.plain)
                    .foregroundStyle(Palette.ink)
            }
        }
        .font(.system(size: 13))
        .padding(.horizontal, 12)
        .frame(height: 34)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Palette.wash))
    }

    private var safeZoneRow: some View {
        HStack(spacing: 10) {
            Text("Show what the app covers")
                .font(.system(size: 12))
                .foregroundStyle(Palette.muted)
            Spacer(minLength: 8)
            SafeZoneSwitch(on: safeZones) {
                withAnimation(Motion.quick) { safeZones.toggle() }
            }
        }
    }

    private var swatchRow: some View {
        HStack(spacing: 10) {
            ForEach(brand.palette) { swatch in
                let selected = headlineColor?.description == swatch.color.description
                Button {
                    withAnimation(Motion.quick) { headlineColor = swatch.color }
                } label: {
                    Circle()
                        .fill(swatch.color)
                        .frame(width: 26, height: 26)
                        .overlay(Circle().strokeBorder(Palette.hairline, lineWidth: 1))
                        .overlay(Circle().strokeBorder(Palette.ink, lineWidth: selected ? 2 : 0).padding(-3))
                }
                .buttonStyle(.plain)
                .help(swatch.name)
            }
        }
    }

    // MARK: Centre — master

    private var masterColumn: some View {
        VStack(spacing: 20) {
            HStack(spacing: 8) {
                ForEach(masterChoices) { option in
                    Choice(text: option.name, on: option.id == masterFormat.id) {
                        withAnimation(Motion.settle) { masterFormat = option }
                    }
                }
                Spacer(minLength: 0)
                Text(masterFormat.label)
                    .font(.system(size: 12).monospaced())
                    .foregroundStyle(Palette.muted)
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)

            // A GeometryReader-sized box (padding applied outside it), with the
            // ad fitted inside via aspectRatio — SwiftUI's own fit math, not a
            // hand-rolled one, so it can never run taller than the box it's in.
            GeometryReader { geo in
                AdComposition(
                    image: image, headline: headline, cta: cta, brandName: brand.name,
                    variant: variant, format: masterFormat,
                    headlineColor: headlineTint, inkText: brand.darkestSwatch.color, coconutFill: brand.lightestSwatch.color,
                    onTapHeadline: { headlineFocused = true }
                )
                .aspectRatio(masterFormat.ratio, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Palette.hairline, lineWidth: 1))
                .shadow(color: .black.opacity(0.1), radius: 26, y: 14)
                .overlay {
                    if safeZones {
                        GeometryReader { box in
                            SafeZoneOverlay(width: box.size.width, height: box.size.height)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
    }

    private var masterChoices: [ZFormat] {
        ["Story", "Square", "Feed"].compactMap { name in ZFormat.all.first { $0.name == name } }
    }

    // MARK: Right — every size

    private var formatsColumn: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHead(title: "Every size", line: "\(ZFormat.all.count) formats, one composition") {
                PrimaryButton(title: "Export all (\(ZFormat.all.count))", action: exportAll)
            }
            .padding(20)
            .padding(.bottom, 4)

            Group {
                if Snapshot.running {
                    formatsGrid
                } else {
                    ScrollView(.vertical, showsIndicators: false) { formatsGrid }
                }
            }
        }
    }

    private var formatsGrid: some View {
        Flow(spacing: 16, line: 18) {
            ForEach(ZFormat.all) { format in
                FormatCard(
                    format: format,
                    image: image, headline: headline, cta: cta, brandName: brand.name,
                    variant: variant,
                    headlineColor: headlineTint, inkText: brand.darkestSwatch.color, coconutFill: brand.lightestSwatch.color,
                    warning: format.id == warningFormat?.id,
                    fixed: warningFixed,
                    onFix: { withAnimation(Motion.settle) { warningFixed = true } }
                )
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 24)
    }

    private func exportAll() {
        let product = brand.products.first { $0.image == image }?.name
        store.keep(ZAsset(.layout, "\(headline), sized for every channel", image: image, product: product, made: "Now"))
    }

    /// Named states for Snapshot: each is rendered to a PNG for review.
    @MainActor static var snapshots: [(String, AnyView)] {
        [
            ("layout-1-master", AnyView(LayoutStudio().frame(width: 1180, height: 740))),
            ("layout-2-safezones", AnyView(
                LayoutStudio(image: "glow", headline: "Summer, bottled honestly.", variant: .bottomBand, safeZones: true)
                    .frame(width: 1180, height: 740)
            )),
        ]
    }
}

// MARK: - A size, small

private struct FormatCard: View {
    let format: ZFormat
    let image: String
    let headline: String
    let cta: String
    let brandName: String
    let variant: AdVariant
    let headlineColor: Color
    let inkText: Color
    let coconutFill: Color
    let warning: Bool
    let fixed: Bool
    let onFix: () -> Void

    private let height: CGFloat = 140

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            AdComposition(
                image: image, headline: headline, cta: cta, brandName: brandName,
                variant: variant, format: format,
                headlineColor: headlineColor, inkText: inkText, coconutFill: coconutFill,
                headlineBoost: warning && !fixed ? 1.4 : 1
            )
            .frame(width: height * format.ratio, height: height)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Palette.hairline, lineWidth: 1))

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(format.name).font(.system(size: 12, weight: .medium)).foregroundStyle(Palette.ink)
                    Text(format.label).font(.system(size: 11).monospaced()).foregroundStyle(Palette.muted)
                }
                Text(format.channel).font(.system(size: 11)).foregroundStyle(Palette.muted)
            }

            if warning {
                if fixed {
                    Tag(text: "Fixed", symbol: "checkmark", strong: true)
                } else {
                    HStack(spacing: 6) {
                        Tag(text: "Headline cropped", symbol: "exclamationmark.triangle")
                        Chip(text: "Fix", action: onFix)
                    }
                }
            }
        }
        .frame(width: max(height * format.ratio, 130), alignment: .leading)
    }
}

// MARK: - Safe zones

/// Thin dashed lines marking the top and bottom bands a Story's own UI
/// (camera controls, reply field) sits over.
private struct SafeZoneOverlay: View {
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        ZStack(alignment: .topLeading) {
            rule.offset(y: height * 0.13)
            rule.offset(y: height * 0.82)
        }
        .frame(width: width, height: height, alignment: .topLeading)
        .allowsHitTesting(false)
    }

    private var rule: some View {
        DashRule()
            .stroke(Color.teal.opacity(0.85), style: StrokeStyle(lineWidth: 1.2, dash: [5, 4]))
            .frame(width: width, height: 1)
    }
}

private struct DashRule: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return path
    }
}

/// A capsule switch: ink when on, wash when off — the same idiom as the
/// brand room's rule toggles, redrawn here since those are file-private.
private struct SafeZoneSwitch: View {
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
