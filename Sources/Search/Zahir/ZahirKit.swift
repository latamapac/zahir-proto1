import SwiftUI
import AppKit

// The kit: the few pieces every Zahir surface is made of, so the image
// studio, the brand room and Figaro's thread read as one product. Built on
// the browser's own Palette and Motion; nothing here picks a colour of its
// own except the brand's swatches.
//
// Rules the pieces keep:
// - One black pill per view: the thing to do next. Everything else is a chip.
// - Cards are white with a hairline and a soft offset shadow; photographs sit
//   a little crooked (Dealt), text sits straight.
// - Headings carry themselves. No small labels above them.

// MARK: - Pictures

/// The demo pictures: bundled with the app, or read from the repository when
/// running straight out of `swift build`.
enum Shots {
    private static var cache: [String: NSImage] = [:]

    static func image(_ name: String) -> NSImage? {
        if let hit = cache[name] { return hit }
        let bundled = Bundle.main.resourceURL?.appendingPathComponent("Zahir/\(name).jpg")
        let source = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Demo/\(name).jpg")
        for url in [bundled, source].compactMap({ $0 }) {
            if let image = NSImage(contentsOf: url) {
                cache[name] = image
                return image
            }
        }
        return nil
    }
}

struct Shot: View {
    let name: String?

    var body: some View {
        if let name, let image = Shots.image(name) {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else {
            Palette.wash
        }
    }
}

/// A grey chip, the way Norma offers "Siri · Action Button · Widget".
struct Chip: View {
    let text: String
    var action: () -> Void = {}
    @State private var over = false

    var body: some View {
        Button(action: action) {
            Text(text)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Palette.ink)
                .padding(.horizontal, 12)
                .frame(height: 30)
                .background(Capsule().fill(over ? Palette.hover : Palette.wash))
        }
        .buttonStyle(.plain)
        .onHover { hovering in withAnimation(Motion.quick) { over = hovering } }
    }
}

/// The one authored moment: answers are dealt onto the table like prints,
/// each a little crooked, and straighten under the pointer.
struct Dealt<Content: View>: View {
    let index: Int
    /// Photographs sit crooked; a card of text sits straight.
    var crooked = true
    @ViewBuilder let content: () -> Content

    @State private var landed = Snapshot.running
    @State private var over = false

    private var rest: Double { crooked ? [-1.6, 1.2, -0.8, 1.4][index % 4] : 0 }

    var body: some View {
        content()
            .shadow(color: .black.opacity(over ? 0.16 : 0.08), radius: over ? 34 : 22, y: over ? 18 : 10)
            .rotationEffect(.degrees(landed ? (over ? 0 : rest) : (crooked ? rest * 5 : 0)))
            .scaleEffect(landed ? (over ? 1.025 : 1) : 0.94)
            .offset(y: landed ? (over ? -4 : 0) : 60)
            .opacity(landed ? 1 : 0)
            .onHover { hovering in
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { over = hovering }
            }
            .onAppear {
                withAnimation(.spring(response: 0.62, dampingFraction: 0.78).delay(0.09 * Double(index))) {
                    landed = true
                }
            }
    }
}

// MARK: - Flow

/// Views laid out like words: left to right, wrapping to a new line.
struct Flow: Layout {
    var spacing: CGFloat = 0
    var line: CGFloat = 0

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, row: CGFloat = 0, widest: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > width, x > 0 {
                y += row + line
                x = 0
                row = 0
            }
            x += size.width + spacing
            row = max(row, size.height)
            widest = max(widest, x - spacing)
        }
        return CGSize(width: min(widest, width), height: y + row)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, row: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                y += row + line
                x = bounds.minX
                row = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            row = max(row, size.height)
        }
    }
}


// MARK: - Buttons

/// The one thing to do next: a black pill.
struct PrimaryButton: View {
    let title: String
    var symbol: String? = nil
    let action: () -> Void
    @State private var over = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let symbol { Image(systemName: symbol).font(.system(size: 12, weight: .semibold)) }
                Text(title).font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(Palette.ground)
            .padding(.horizontal, 18)
            .frame(height: 36)
            .background(Capsule().fill(Palette.ink.opacity(over ? 0.86 : 1)))
        }
        .buttonStyle(.plain)
        .onHover { hovering in withAnimation(Motion.quick) { over = hovering } }
    }
}

/// A round, quiet button for a single symbol: close, more, back.
struct IconButton: View {
    let symbol: String
    var help: String = ""
    let action: () -> Void
    @State private var over = false

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(over ? Palette.ink : Palette.muted)
                .frame(width: 30, height: 30)
                .background(Circle().fill(over ? Palette.hover : .clear))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help(help)
        .onHover { hovering in withAnimation(Motion.quick) { over = hovering } }
    }
}

/// A chip that stays chosen: filters, tabs inside a surface, options.
struct Choice: View {
    let text: String
    let on: Bool
    var symbol: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if let symbol { Image(systemName: symbol).font(.system(size: 11, weight: .medium)) }
                Text(text).font(.system(size: 13, weight: .medium))
            }
            .foregroundStyle(on ? Palette.ground : Palette.ink)
            .padding(.horizontal, 12)
            .frame(height: 30)
            .background(Capsule().fill(on ? Palette.ink : Palette.wash))
        }
        .buttonStyle(.plain)
        .animation(Motion.quick, value: on)
    }
}

// MARK: - Small things

/// A small grey label: sizes, tools used, statuses.
struct Tag: View {
    let text: String
    var symbol: String? = nil
    var strong = false

    var body: some View {
        HStack(spacing: 4) {
            if let symbol { Image(systemName: symbol).font(.system(size: 10, weight: .medium)) }
            Text(text).font(.system(size: 11, weight: .medium).monospacedDigit())
        }
        .foregroundStyle(strong ? Palette.ink : Palette.ink.opacity(0.7))
        .padding(.horizontal, 8)
        .frame(height: 22)
        .background(Capsule().fill(Palette.wash))
    }
}

/// A numbered circle, the way Norma counts its steps.
struct NumberBadge: View {
    let number: Int
    var filled = false

    var body: some View {
        Text("\(number)")
            .font(.system(size: 12, weight: .semibold).monospacedDigit())
            .foregroundStyle(filled ? Palette.ground : Palette.ink)
            .frame(width: 26, height: 26)
            .background(Circle().fill(filled ? Palette.ink : Palette.ground))
            .overlay(Circle().strokeBorder(filled ? .clear : Palette.hairline, lineWidth: 1))
    }
}

/// Figaro's mark: a black disc with a spark.
struct FigaroMark: View {
    var size: CGFloat = 22

    var body: some View {
        ZStack {
            Circle().fill(Palette.ink)
            Image(systemName: "sparkle")
                .font(.system(size: size * 0.45, weight: .semibold))
                .foregroundStyle(Palette.ground)
        }
        .frame(width: size, height: size)
    }
}

/// A person or a brand as a disc: a picture if there is one, else a letter.
struct Avatar: View {
    let letter: String
    var image: String? = nil
    var size: CGFloat = 32
    var tint: Color = Palette.ink

    var body: some View {
        ZStack {
            if let image {
                Shot(name: image)
            } else {
                tint
                Text(letter)
                    .font(.system(size: size * 0.42, weight: .semibold))
                    .foregroundStyle(Palette.ground)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }
}

/// A colour from the brand, with its name and code under it.
struct SwatchChip: View {
    let swatch: ZSwatch
    var size: CGFloat = 72

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(swatch.color)
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Palette.hairline, lineWidth: 1))
                .frame(width: size, height: size)
            Text(swatch.name).font(.system(size: 12, weight: .medium)).foregroundStyle(Palette.ink)
            Text(swatch.hex).font(.system(size: 11).monospaced()).foregroundStyle(Palette.muted)
        }
    }
}

extension Color {
    /// "#EADBC0" or "EADBC0".
    init(hex: String) {
        let clean = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let value = UInt64(clean, radix: 16) ?? 0
        self.init(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }
}

// MARK: - Containers

extension View {
    /// The white card: hairline, soft offset shadow.
    func zCard(radius: CGFloat = 20, padding: CGFloat = 20, shadow: Bool = true) -> some View {
        self
            .padding(padding)
            .background(RoundedRectangle(cornerRadius: radius, style: .continuous).fill(Palette.ground))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(Palette.hairline, lineWidth: 1))
            .shadow(color: .black.opacity(shadow ? 0.06 : 0), radius: 24, y: 10)
    }

    /// A hairline under a row.
    func zRule() -> some View {
        overlay(alignment: .bottom) { Rectangle().fill(Palette.hairline).frame(height: 1) }
    }
}

/// A Zahir surface as a page in a tab: its title, one plain line under it,
/// actions on the right, and the content in a centred column.
struct SurfacePage<Trailing: View, Content: View>: View {
    let title: String
    var line: String? = nil
    var width: CGFloat = 1080
    @ViewBuilder var trailing: () -> Trailing
    @ViewBuilder var content: () -> Content

    var body: some View {
        Group {
            if Snapshot.running {
                // Top of the page, as the scroll view would show it.
                column.fixedSize(horizontal: false, vertical: true).frame(maxHeight: .infinity, alignment: .top)
            } else {
                ScrollView(.vertical) { column }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.ground)
    }

    private var column: some View {
        VStack(alignment: .leading, spacing: 28) {
            HStack(alignment: .firstTextBaseline, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.system(size: 28, weight: .semibold))
                        .tracking(-0.5)
                        .foregroundStyle(Palette.ink)
                    if let line {
                        Text(line)
                            .font(.system(size: 14))
                            .foregroundStyle(Palette.muted)
                    }
                }
                Spacer(minLength: 0)
                HStack(spacing: 8) { trailing() }
            }
            content()
        }
        .padding(.horizontal, 40)
        .padding(.top, 36)
        .padding(.bottom, 64)
        .frame(maxWidth: width)
        .frame(maxWidth: .infinity)
    }
}

extension SurfacePage where Trailing == EmptyView {
    init(title: String, line: String? = nil, width: CGFloat = 1080, @ViewBuilder content: @escaping () -> Content) {
        self.init(title: title, line: line, width: width, trailing: { EmptyView() }, content: content)
    }
}

/// A section inside a surface: a plain heading, maybe an action beside it.
struct SectionHead<Trailing: View>: View {
    let title: String
    var line: String? = nil
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                    .tracking(-0.2)
                    .foregroundStyle(Palette.ink)
                if let line {
                    Text(line).font(.system(size: 13)).foregroundStyle(Palette.muted)
                }
            }
            Spacer(minLength: 0)
            trailing()
        }
    }
}

extension SectionHead where Trailing == EmptyView {
    init(title: String, line: String? = nil) {
        self.init(title: title, line: line, trailing: { EmptyView() })
    }
}

/// Nothing here yet, said plainly, with the one thing that would change it.
struct EmptyState: View {
    let symbol: String
    let title: String
    let line: String
    var action: (String, () -> Void)? = nil

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(Palette.muted)
                .frame(width: 52, height: 52)
                .background(Circle().fill(Palette.wash))
            Text(title).font(.system(size: 17, weight: .semibold)).foregroundStyle(Palette.ink)
            Text(line)
                .font(.system(size: 14))
                .foregroundStyle(Palette.muted)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)
            if let action {
                PrimaryButton(title: action.0, action: action.1).padding(.top, 6)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 56)
    }
}

// MARK: - Toasts

/// What just happened, at the bottom of the page, with Undo when it can be.
struct ToastHost: View {
    @ObservedObject var store = ZahirStore.shared

    var body: some View {
        VStack(spacing: 8) {
            ForEach(store.toasts) { toast in
                HStack(spacing: 12) {
                    Image(systemName: toast.symbol)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Palette.ground)
                    Text(toast.text)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Palette.ground)
                    if let undo = toast.undo {
                        Button {
                            undo()
                            store.dismiss(toast.id)
                        } label: {
                            Text("Undo")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Palette.ground)
                                .underline()
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .frame(height: 40)
                .background(Capsule().fill(Palette.ink))
                .shadow(color: .black.opacity(0.18), radius: 18, y: 8)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(Motion.settle, value: store.toasts.map(\.id))
        .allowsHitTesting(!store.toasts.isEmpty)
    }
}

