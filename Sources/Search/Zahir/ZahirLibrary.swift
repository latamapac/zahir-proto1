import SwiftUI
import AppKit

// Everything you and Figaro made, in one place — the whole pitch of Zahir in
// a single surface. A masonry wall of what exists (pictures dealt in at a
// tilt, text sitting straight) with filters plain enough to find one piece
// among many, and a batch bar for doing something to several at once.

private enum LibraryViewMode { case grid, list }
private enum LibraryAuthor { case all, figaro, you }

struct LibrarySurface: View {
    @ObservedObject var store = ZahirStore.shared

    @State private var query = ""
    @State private var viewMode: LibraryViewMode = .grid
    @State private var kindFilter: ZAssetKind?
    @State private var productFilter: String?
    @State private var statusFilter: ZStatus?
    @State private var authorFilter: LibraryAuthor = .all
    @State private var selected: Set<UUID>

    /// `selected` renders a state directly, for Snapshot, without touching
    /// the shared store.
    init(selected: Set<UUID> = []) {
        _selected = State(initialValue: selected)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            SurfacePage(
                title: "Library",
                line: "Everything you and Figaro made. \(store.assets.count) pieces this week.",
                width: 1140,
                trailing: {
                    searchField
                    HStack(spacing: 2) {
                        Choice(text: "Grid", on: viewMode == .grid, symbol: "square.grid.2x2") {
                            withAnimation(Motion.quick) { viewMode = .grid }
                        }
                        Choice(text: "List", on: viewMode == .list, symbol: "list.bullet") {
                            withAnimation(Motion.quick) { viewMode = .list }
                        }
                    }
                    PrimaryButton(title: "Ask Figaro for more", symbol: "sparkle") {
                        ZahirNav.open(.figaro)
                    }
                }
            ) {
                VStack(alignment: .leading, spacing: 28) {
                    filterRow
                    if filteredAssets.isEmpty {
                        EmptyState(
                            symbol: "square.stack",
                            title: "Nothing matches",
                            line: "Try a different search, or clear the filters.",
                            action: ("Clear filters", { clearFilters() })
                        )
                    } else if viewMode == .grid {
                        masonryGrid
                    } else {
                        listRows
                    }
                }
            }

            if !selected.isEmpty {
                batchBar
                    .padding(.bottom, 28)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(Motion.settle, value: selected.isEmpty)
    }

    // MARK: - Trailing

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Palette.muted)
            Group {
                if Snapshot.running {
                    Text(query.isEmpty ? "Search title or product" : query)
                        .foregroundStyle(query.isEmpty ? Palette.muted : Palette.ink)
                } else {
                    TextField("Search title or product", text: $query)
                        .textFieldStyle(.plain)
                        .foregroundStyle(Palette.ink)
                }
            }
            .font(.system(size: 13))
        }
        .padding(.horizontal, 12)
        .frame(width: 210, height: 32)
        .background(Capsule().fill(Palette.wash))
    }

    // MARK: - Filters

    private var filterRow: some View {
        VStack(alignment: .leading, spacing: 12) {
            filterLine("Kind") {
                Choice(text: "All", on: kindFilter == nil) {
                    withAnimation(Motion.quick) { kindFilter = nil }
                }
                ForEach(ZAssetKind.allCases, id: \.self) { kind in
                    Choice(text: kind.name, on: kindFilter == kind, symbol: kind.symbol) {
                        withAnimation(Motion.quick) { kindFilter = (kindFilter == kind) ? nil : kind }
                    }
                }
            }
            filterLine("Product") {
                Choice(text: "All", on: productFilter == nil) {
                    withAnimation(Motion.quick) { productFilter = nil }
                }
                ForEach(store.brand.products) { product in
                    Choice(text: product.name, on: productFilter == product.name) {
                        withAnimation(Motion.quick) { productFilter = (productFilter == product.name) ? nil : product.name }
                    }
                }
            }
            filterLine("Status") {
                Choice(text: "All", on: statusFilter == nil) {
                    withAnimation(Motion.quick) { statusFilter = nil }
                }
                ForEach(ZStatus.allCases, id: \.self) { status in
                    Choice(text: status.name, on: statusFilter == status) {
                        withAnimation(Motion.quick) { statusFilter = (statusFilter == status) ? nil : status }
                    }
                }
            }
            filterLine("Made by") {
                Choice(text: "All", on: authorFilter == .all) {
                    withAnimation(Motion.quick) { authorFilter = .all }
                }
                Choice(text: "Figaro", on: authorFilter == .figaro, symbol: "sparkle") {
                    withAnimation(Motion.quick) { authorFilter = .figaro }
                }
                Choice(text: "You", on: authorFilter == .you) {
                    withAnimation(Motion.quick) { authorFilter = .you }
                }
            }
        }
    }

    private func filterLine<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Palette.muted)
                .frame(width: 56, alignment: .leading)
                .padding(.top, 5)
            Flow(spacing: 8, line: 8) { content() }
        }
    }

    // MARK: - Filtering

    private var filteredAssets: [ZAsset] {
        store.assets.filter { asset in
            if let kindFilter, asset.kind != kindFilter { return false }
            if let productFilter, asset.product != productFilter { return false }
            if let statusFilter, asset.status != statusFilter { return false }
            switch authorFilter {
            case .all: break
            case .figaro: if !asset.byFigaro { return false }
            case .you: if asset.byFigaro { return false }
            }
            let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if !q.isEmpty {
                let inTitle = asset.title.lowercased().contains(q)
                let inProduct = (asset.product ?? "").lowercased().contains(q)
                if !inTitle && !inProduct { return false }
            }
            return true
        }
    }

    private func clearFilters() {
        withAnimation(Motion.quick) {
            query = ""
            kindFilter = nil
            productFilter = nil
            statusFilter = nil
            authorFilter = .all
        }
    }

    // MARK: - Grid: a masonry feel from three balanced columns

    private func isPictureKind(_ kind: ZAssetKind) -> Bool {
        switch kind {
        case .image, .video, .layout, .post: return true
        case .copy, .read: return false
        }
    }

    private func estimatedHeight(_ asset: ZAsset) -> CGFloat {
        isPictureKind(asset.kind) ? 300 : 190
    }

    private var masonryColumns: [[(Int, ZAsset)]] {
        let count = 3
        var buckets: [[(Int, ZAsset)]] = Array(repeating: [], count: count)
        var heights = [CGFloat](repeating: 0, count: count)
        for pair in Array(filteredAssets.enumerated()) {
            let i = heights.indices.min { heights[$0] < heights[$1] } ?? 0
            buckets[i].append(pair)
            heights[i] += estimatedHeight(pair.1)
        }
        return buckets
    }

    private var masonryGrid: some View {
        HStack(alignment: .top, spacing: 20) {
            ForEach(Array(masonryColumns.enumerated()), id: \.offset) { _, column in
                LazyVStack(spacing: 20) {
                    ForEach(column, id: \.1.id) { index, asset in
                        Dealt(index: index, crooked: isPictureKind(asset.kind)) {
                            LibraryCard(
                                asset: asset,
                                index: index,
                                selected: selected.contains(asset.id),
                                onToggleSelect: { toggleSelect(asset.id) },
                                onOpen: { openInStudio(asset) },
                                onDuplicate: { duplicate(asset) },
                                onDelete: { delete(asset) }
                            )
                        }
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - List

    private var listRows: some View {
        VStack(spacing: 2) {
            ForEach(filteredAssets) { asset in
                LibraryRow(
                    asset: asset,
                    selected: selected.contains(asset.id),
                    onToggleSelect: { toggleSelect(asset.id) },
                    onOpen: { openInStudio(asset) },
                    onDuplicate: { duplicate(asset) },
                    onDelete: { delete(asset) }
                )
            }
        }
    }

    // MARK: - Batch bar

    private var batchBar: some View {
        HStack(spacing: 14) {
            Text("\(selected.count) selected")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Palette.ground)
            divider
            batchAction("Resize all") { store.toast("Resizing \(selected.count) pieces") }
            batchAction("Schedule") { store.toast("Scheduling \(selected.count) pieces") }
            batchAction("Delete") { batchDeleteAll() }
            divider
            batchAction("Clear") { withAnimation(Motion.quick) { selected.removeAll() } }
        }
        .padding(.horizontal, 18)
        .frame(height: 44)
        .background(Capsule().fill(Palette.ink))
        .shadow(color: .black.opacity(0.22), radius: 24, y: 10)
    }

    private var divider: some View {
        Rectangle().fill(Palette.ground.opacity(0.25)).frame(width: 1, height: 16)
    }

    private func batchAction(_ text: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(text)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Palette.ground)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Actions

    private func toggleSelect(_ id: UUID) {
        if selected.contains(id) { selected.remove(id) } else { selected.insert(id) }
    }

    private func studioRoute(for kind: ZAssetKind) -> ZahirRoute {
        switch kind {
        case .image: return .image
        case .video: return .video
        case .copy: return .copy
        case .post: return .copy
        case .layout: return .layout
        case .read: return .research
        }
    }

    private func openInStudio(_ asset: ZAsset) {
        let card = Answer.Card(image: asset.image, title: asset.title, line: asset.product ?? asset.channel ?? "")
        Studio.open(card, in: studioRoute(for: asset.kind))
    }

    private func duplicate(_ asset: ZAsset) {
        guard let index = store.assets.firstIndex(where: { $0.id == asset.id }) else { return }
        let copy = ZAsset(
            asset.kind, asset.title, image: asset.image, product: asset.product,
            channel: asset.channel, byFigaro: asset.byFigaro, made: "Now", status: asset.status
        )
        store.assets.insert(copy, at: index)
        let copyID = copy.id
        store.toast("Duplicated", undo: {
            ZahirStore.shared.assets.removeAll { $0.id == copyID }
        })
    }

    private func delete(_ asset: ZAsset) {
        guard let index = store.assets.firstIndex(where: { $0.id == asset.id }) else { return }
        store.assets.remove(at: index)
        selected.remove(asset.id)
        store.toast("Deleted", symbol: "trash", undo: {
            guard !ZahirStore.shared.assets.contains(where: { $0.id == asset.id }) else { return }
            ZahirStore.shared.assets.insert(asset, at: min(index, ZahirStore.shared.assets.count))
        })
    }

    private func batchDeleteAll() {
        let ids = selected
        guard !ids.isEmpty else { return }
        let removed = store.assets.filter { ids.contains($0.id) }
        withAnimation(Motion.settle) {
            store.assets.removeAll { ids.contains($0.id) }
            selected.removeAll()
        }
        store.toast("\(removed.count) deleted", symbol: "trash", undo: {
            for asset in removed where !ZahirStore.shared.assets.contains(where: { $0.id == asset.id }) {
                ZahirStore.shared.assets.insert(asset, at: 0)
            }
        })
    }

    /// Named states for Snapshot: each is rendered to a PNG for review.
    @MainActor static var snapshots: [(String, AnyView)] {
        let firstThree = Set(ZahirStore.shared.assets.prefix(3).map(\.id))
        return [
            ("library-1-grid", AnyView(LibrarySurface().frame(width: 1180, height: 740))),
            ("library-2-selected", AnyView(LibrarySurface(selected: firstThree).frame(width: 1180, height: 740))),
        ]
    }
}

// MARK: - Grid card

private struct LibraryCard: View {
    let asset: ZAsset
    let index: Int
    let selected: Bool
    let onToggleSelect: () -> Void
    let onOpen: () -> Void
    let onDuplicate: () -> Void
    let onDelete: () -> Void
    @State private var over = false

    private static let aspects: [CGFloat] = [4 / 5, 1, 5 / 6, 3 / 4]
    private var isPicture: Bool {
        switch asset.kind {
        case .image, .video, .layout, .post: return true
        case .copy, .read: return false
        }
    }
    private var aspect: CGFloat { Self.aspects[index % Self.aspects.count] }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if isPicture { pictureBlock } else { textBlock }
            meta
        }
        .zCard(radius: 20, padding: isPicture ? 12 : 18)
        .onHover { hovering in withAnimation(Motion.quick) { over = hovering } }
        .onTapGesture { if NSEvent.modifierFlags.contains(.command) { onToggleSelect() } }
        .animation(Motion.quick, value: over)
    }

    private var pictureBlock: some View {
        ZStack(alignment: .topLeading) {
            Color.clear
                .aspectRatio(aspect, contentMode: .fit)
                .overlay { Shot(name: asset.image) }
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Palette.hairline, lineWidth: 1))

            HStack {
                checkbox
                Spacer(minLength: 0)
                if asset.byFigaro { FigaroMark(size: 20) }
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

    private var textBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                checkbox
                Spacer(minLength: 0)
                if asset.byFigaro { FigaroMark(size: 18) }
            }
            Image(systemName: asset.kind.symbol)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Palette.muted)
            Text(asset.title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
            actionRow
                .opacity(over ? 1 : 0)
                .allowsHitTesting(over)
        }
    }

    private var meta: some View {
        VStack(alignment: .leading, spacing: 6) {
            if isPicture {
                Text(asset.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(2)
            }
            HStack(spacing: 6) {
                Tag(text: asset.kind.name, symbol: asset.kind.symbol)
                if let product = asset.product { Tag(text: product) }
                Tag(text: asset.status.name, strong: asset.status == .live || asset.status == .approved)
            }
            HStack(spacing: 5) {
                if let channel = asset.channel {
                    Text(channel).font(.system(size: 11)).foregroundStyle(Palette.muted)
                    Text("·").font(.system(size: 11)).foregroundStyle(Palette.faint)
                }
                Text(asset.made).font(.system(size: 11)).foregroundStyle(Palette.muted)
            }
        }
    }

    private var checkbox: some View {
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
            .frame(width: 22, height: 22)
            .shadow(color: .black.opacity(0.12), radius: 4, y: 2)
        }
        .buttonStyle(.plain)
        .opacity(selected || over ? 1 : 0)
    }

    private var actionRow: some View {
        HStack(spacing: 6) {
            Chip(text: "Open in studio", action: onOpen)
            Chip(text: "Duplicate", action: onDuplicate)
            Chip(text: "Delete", action: onDelete)
        }
    }
}

// MARK: - List row

private struct LibraryRow: View {
    let asset: ZAsset
    let selected: Bool
    let onToggleSelect: () -> Void
    let onOpen: () -> Void
    let onDuplicate: () -> Void
    let onDelete: () -> Void
    @State private var over = false

    var body: some View {
        HStack(spacing: 14) {
            checkbox
            thumb
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(asset.title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Palette.ink)
                        .lineLimit(1)
                    if asset.byFigaro { FigaroMark(size: 15) }
                }
                HStack(spacing: 5) {
                    Text(asset.product ?? "No product").font(.system(size: 11)).foregroundStyle(Palette.muted)
                    if let channel = asset.channel {
                        Text("·").font(.system(size: 11)).foregroundStyle(Palette.faint)
                        Text(channel).font(.system(size: 11)).foregroundStyle(Palette.muted)
                    }
                }
            }
            Spacer(minLength: 8)
            Tag(text: asset.kind.name, symbol: asset.kind.symbol)
            Tag(text: asset.status.name)
            Text(asset.made)
                .font(.system(size: 12))
                .foregroundStyle(Palette.muted)
                .frame(width: 72, alignment: .trailing)
            HStack(spacing: 2) {
                IconButton(symbol: "arrow.up.forward.square", help: "Open in studio", action: onOpen)
                IconButton(symbol: "plus.square.on.square", help: "Duplicate", action: onDuplicate)
                IconButton(symbol: "trash", help: "Delete", action: onDelete)
            }
            .opacity(over ? 1 : 0)
            .allowsHitTesting(over)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(over ? Palette.hover : .clear))
        .onHover { hovering in withAnimation(Motion.quick) { over = hovering } }
        .onTapGesture { if NSEvent.modifierFlags.contains(.command) { onToggleSelect() } }
        .animation(Motion.quick, value: over)
    }

    private var thumb: some View {
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
        .frame(width: 42, height: 42)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var checkbox: some View {
        Button(action: onToggleSelect) {
            ZStack {
                Circle().fill(selected ? Palette.ink : Palette.ground)
                Circle().strokeBorder(Palette.hairline, lineWidth: selected ? 0 : 1)
                if selected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Palette.ground)
                }
            }
            .frame(width: 18, height: 18)
        }
        .buttonStyle(.plain)
        .opacity(selected || over ? 1 : 0)
    }
}
