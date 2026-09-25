import SwiftUI

// Zahir's surfaces open as ordinary tabs at zahir:// addresses, so the image
// studio sits in the row next to Instagram and a competitor's site, and you
// flip between them the way you flip between any two pages. Tab.go(to:)
// never hands these to WebKit; Page draws ZahirSurface instead.

enum ZahirRoute: String, CaseIterable, Hashable {
    case home, hire, brand, figaro, image, video, layout, copy, research, calendar, results, library, inbox, playbooks

    var url: URL { URL(string: "zahir://\(rawValue)")! }

    init?(_ url: URL?) {
        guard let url, url.scheme == "zahir",
              let route = ZahirRoute(rawValue: (url.host() ?? "").lowercased()) else { return nil }
        self = route
    }

    var title: String {
        switch self {
        case .home: "Zahir"
        case .hire: "Hire Figaro"
        case .brand: "Brand"
        case .figaro: "Figaro"
        case .image: "Image studio"
        case .video: "Video studio"
        case .layout: "Layout"
        case .copy: "Copy desk"
        case .research: "Research"
        case .calendar: "Calendar"
        case .results: "Results"
        case .library: "Library"
        case .inbox: "Inbox"
        case .playbooks: "Playbooks"
        }
    }

    var symbol: String {
        switch self {
        case .home: "house"
        case .hire: "person.badge.plus"
        case .brand: "seal"
        case .figaro: "sparkle"
        case .image: "photo"
        case .video: "film"
        case .layout: "rectangle.3.group"
        case .copy: "text.alignleft"
        case .research: "magnifyingglass"
        case .calendar: "calendar"
        case .results: "chart.line.uptrend.xyaxis"
        case .library: "square.stack"
        case .inbox: "tray"
        case .playbooks: "book.closed"
        }
    }

    /// Which wave builds it; surfaces not built yet say so.
    var wave: Int {
        switch self {
        case .home, .hire, .brand, .figaro: 1
        case .image, .video, .layout, .copy: 2
        case .research, .calendar, .results, .library, .inbox, .playbooks: 3
        }
    }
}

/// The page a Zahir tab shows.
struct ZahirSurface: View {
    let route: ZahirRoute

    var body: some View {
        Group {
            switch route {
            case .hire: HireFigaro()
            case .brand: BrandRoom()
            case .figaro: FigaroThread()
            case .home: ZahirHome()
            case .image: ImageStudio()
            case .video: VideoStudio()
            case .layout: LayoutStudio()
            case .copy: CopyDesk()
            case .research: ResearchBoard()
            case .calendar: CalendarSurface()
            case .results: ResultsSurface()
            case .library: LibrarySurface()
            case .inbox: InboxSurface()
            case .playbooks: PlaybooksSurface()
            default: Soon(route: route)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.ground)
    }
}

/// A surface that isn't built yet: named, with what it will do.
private struct Soon: View {
    let route: ZahirRoute

    var body: some View {
        EmptyState(
            symbol: route.symbol,
            title: route.title,
            line: "Coming in wave \(route.wave) of Zahir proto1. Until then, ask Figaro (⌘J) and it will make the thing here for you."
        )
    }
}

/// How a surface opens another surface without holding the browser itself.
@MainActor
enum ZahirNav {
    static weak var browser: Browser?

    static func open(_ route: ZahirRoute) { browser?.openZahir(route) }
}

extension Browser {
    /// Open a Zahir surface. Zahir keeps to one tab: if one is open, it moves
    /// there (and is brought forward) rather than adding another. Hold ⌘ to
    /// open the surface in a tab of its own, for two side by side.
    func openZahir(_ route: ZahirRoute) {
        if let tab = tabs.first(where: { ZahirRoute($0.address) == route }) {
            select(tab)
            return
        }
        let separate = NSEvent.modifierFlags.contains(.command)
        if !separate, let tab = zahirTab {
            tab.go(to: route.url)
            select(tab)
            return
        }
        _ = open(route.url, foreground: true, atEnd: true)
    }

    /// The Zahir tab to reuse: the one in front if it is Zahir's, else the
    /// most recently used.
    private var zahirTab: Tab? {
        if let active, ZahirRoute(active.address) != nil { return active }
        return tabs.filter { ZahirRoute($0.address) != nil }.max { $0.touched < $1.touched }
    }
}

/// Zahir's places, like a phone's app grid. In the tab strip it opens from
/// the nine dots as a launcher; in the sidebar it folds to one line (the brand
/// and the dots) and opens in place.
struct ZahirDock: View {
    @ObservedObject var browser: Browser
    /// The strip's popover: always open, four across.
    var launcher = false
    /// Called after a place is picked (the strip's popover closes on it).
    var picked: () -> Void = {}
    @ObservedObject private var store = ZahirStore.shared

    static let places: [ZahirRoute] = [.figaro, .inbox, .brand, .playbooks, .image, .video, .layout, .copy, .research, .calendar, .results, .library]
    private static let tile: CGFloat = 58
    private static let gap: CGFloat = 6

    /// The sidebar's measure of it, for where its window-dragging band ends.
    @MainActor static var height: CGFloat {
        let rows = CGFloat((places.count + 2) / 3)
        let grid = ZahirStore.shared.dockOpen ? 8 + rows * tile + (rows - 1) * gap : 0
        return BrandSwitch.height + grid + 12
    }

    private var open: Bool { launcher || store.dockOpen }

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 4) {
                BrandSwitch()
                if !launcher {
                    NineDots(on: store.dockOpen) {
                        withAnimation(Motion.settle) { store.dockOpen.toggle() }
                    }
                }
            }
            if open {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Self.gap), count: launcher ? 4 : 3),
                          spacing: Self.gap) {
                    ForEach(Self.places, id: \.self) { route in
                        DockTile(route: route, live: ZahirRoute(browser.active?.address) == route) {
                            browser.openZahir(route)
                            picked()
                        }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
            if launcher {
                HStack {
                    Text("Hold ⌘ to open in a new tab")
                        .font(.system(size: 11))
                        .foregroundStyle(Palette.muted)
                    Spacer(minLength: 0)
                    Button {
                        ZahirNav.open(.home)
                        picked()
                    } label: {
                        Text("Home").font(.system(size: 11, weight: .medium)).foregroundStyle(Palette.ink)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 4)
            }
        }
        .padding(.bottom, launcher ? 0 : 12)
    }
}

/// The nine dots: Zahir, folded.
private struct NineDots: View {
    let on: Bool
    let action: () -> Void
    @State private var over = false

    var body: some View {
        Button(action: action) {
            Image(systemName: "circle.grid.3x3")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(on ? Palette.ground : Palette.ink.opacity(0.75))
                .frame(width: 32, height: BrandSwitch.height)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(on ? Palette.ink : (over ? Palette.hover : .clear))
                )
        }
        .buttonStyle(.plain)
        .help(on ? "Fold Zahir away" : "Zahir")
        .onHover { hovering in withAnimation(Motion.quick) { over = hovering } }
    }
}

/// One place: an icon on a soft square, its name under it, and whatever is
/// happening there in the background.
private struct DockTile: View {
    let route: ZahirRoute
    let live: Bool
    let action: () -> Void
    @State private var over = false
    @ObservedObject private var store = ZahirStore.shared

    private var waiting: Int {
        route == .inbox ? store.inbox.filter { $0.kind == .approval }.count : 0
    }
    private var progress: Double? {
        guard route == .playbooks, let run = store.playbooks.first(where: \.running), !run.steps.isEmpty else { return nil }
        return Double(run.steps.filter(\.done).count) / Double(run.steps.count)
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: route.symbol)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(live ? Palette.ground : Palette.ink.opacity(0.8))
                    .frame(width: 36, height: 36)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(live ? Palette.ink : (over ? Palette.hover : Palette.wash))
                    )
                    .overlay(alignment: .topTrailing) {
                        if waiting > 0 {
                            Text("\(waiting)")
                                .font(.system(size: 9, weight: .bold).monospacedDigit())
                                .foregroundStyle(Palette.ground)
                                .frame(minWidth: 15, minHeight: 15)
                                .background(Circle().fill(Palette.ink).overlay(Circle().strokeBorder(Palette.ground, lineWidth: 1.5)))
                                .offset(x: 5, y: -5)
                        }
                    }
                    .overlay(alignment: .bottom) {
                        if let progress {
                            Capsule().fill(live ? Palette.ground.opacity(0.35) : Palette.hairline)
                                .frame(width: 22, height: 2)
                                .overlay(alignment: .leading) {
                                    Capsule().fill(live ? Palette.ground : Palette.ink).frame(width: 22 * progress, height: 2)
                                }
                                .padding(.bottom, 4)
                        }
                    }
                Text(route.title)
                    .font(.system(size: 10.5, weight: live ? .semibold : .regular))
                    .foregroundStyle(Palette.ink.opacity(live ? 1 : 0.75))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 58)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(route.title)
        .onHover { hovering in withAnimation(Motion.quick) { over = hovering } }
        .animation(Motion.settle, value: waiting)
    }
}

/// Taking something Figaro made into the studio that can work on it.
@MainActor
enum Studio {
    static func open(_ answer: Answer) {
        let route: ZahirRoute = switch answer.kind {
        case .concepts: .image
        case .storyboard: .video
        case .post: .copy
        case .read: .research
        }
        open(answer.cards.first ?? Answer.Card(image: nil, title: answer.heading, line: ""), in: route)
    }

    static func open(_ card: Answer.Card, in route: ZahirRoute) {
        ZahirStore.shared.handoff = card
        if Figaro.shared.showing { Figaro.shared.close() }
        ZahirNav.open(route)
    }
}

extension Browser {
    /// Zahir's surfaces whose names start with (or contain) what was typed,
    /// for the field and for ⌘K.
    func zahirPlaces(matching typed: String, limit: Int) -> [Suggestion] {
        let needle = typed.trimmingCharacters(in: .whitespaces).lowercased()
        guard needle.count >= 2, limit > 0 else { return [] }
        return ZahirRoute.allCases
            .filter { $0.title.lowercased().contains(needle) || $0.rawValue.hasPrefix(needle) }
            .sorted { a, b in a.title.lowercased().hasPrefix(needle) && !b.title.lowercased().hasPrefix(needle) }
            .prefix(limit)
            .map { Suggestion(key: $0.title, title: "Zahir", url: $0.url, kind: .zahir) }
    }
}

/// Which brand Zahir is working on. One for most people; an agency runs
/// several, and every surface follows the one picked here.
struct BrandSwitch: View {
    @ObservedObject var store = ZahirStore.shared
    @State private var over = false

    static let height: CGFloat = 36

    var body: some View {
        Menu {
            ForEach(store.brands) { brand in
                Button {
                    withAnimation(Motion.settle) { store.brandID = brand.id }
                    store.toast("Working on \(brand.name)", symbol: "arrow.left.arrow.right")
                } label: {
                    if brand.id == store.brandID {
                        Label(brand.name, systemImage: "checkmark")
                    } else {
                        Text(brand.name)
                    }
                }
            }
            Divider()
            Button("Add a brand…") { ZahirNav.open(.hire) }
        } label: {
            HStack(spacing: 8) {
                Avatar(letter: store.brand.letter, size: 22)
                Text(store.brand.name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                Spacer(minLength: 0)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Palette.muted)
            }
            .padding(.horizontal, 8)
            .frame(height: Self.height)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(over ? Palette.hover : .clear))
            .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .onHover { hovering in withAnimation(Motion.quick) { over = hovering } }
    }
}
