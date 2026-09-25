import SwiftUI

// What Figaro did while you were away, and what it needs from you before it
// goes further. Approvals first — bigger cards, because they're the one
// thing that stalls without you — then what's still running, what Figaro
// noticed on its own, and the quiet trail of what's already done.

private enum InboxFilter: CaseIterable {
    case all, needsYou, done, noticed

    var title: String {
        switch self {
        case .all: "All"
        case .needsYou: "Needs you"
        case .done: "Done"
        case .noticed: "Noticed"
        }
    }
}

struct InboxSurface: View {
    @ObservedObject var store = ZahirStore.shared
    @State private var filter: InboxFilter = .all

    var body: some View {
        SurfacePage(
            title: "Inbox",
            line: "What Figaro did, and what it needs from you.",
            width: 880,
            trailing: {
                HStack(spacing: 6) {
                    ForEach(InboxFilter.allCases, id: \.self) { f in
                        Choice(text: f.title, on: f == filter) {
                            withAnimation(Motion.quick) { filter = f }
                        }
                    }
                }
                PrimaryButton(title: "Approve all (\(approvalItems.count))", symbol: "checkmark") {
                    approveAll()
                }
            }
        ) {
            VStack(alignment: .leading, spacing: 36) {
                if (filter == .all || filter == .needsYou), !approvalItems.isEmpty {
                    group("Needs you") {
                        VStack(spacing: 14) {
                            ForEach(approvalItems) { item in
                                ApprovalCard(
                                    item: item,
                                    onApprove: { approve(item) },
                                    onChange: { ZahirNav.open(.figaro) },
                                    onOpen: { open(item) }
                                )
                                .transition(.asymmetric(
                                    insertion: .opacity,
                                    removal: .move(edge: .trailing).combined(with: .opacity)
                                ))
                            }
                        }
                    }
                }

                if filter == .all, !runningItems.isEmpty {
                    group("Working") {
                        VStack(spacing: 12) {
                            ForEach(runningItems) { item in
                                RunningRow(item: item, onOpen: { open(item) })
                            }
                        }
                    }
                }

                if (filter == .all || filter == .noticed), !noticedItems.isEmpty {
                    group("Figaro noticed") {
                        VStack(spacing: 10) {
                            ForEach(noticedItems) { item in
                                NoticedRow(item: item, onAct: { open(item) })
                            }
                        }
                    }
                }

                if (filter == .all || filter == .done), !doneItems.isEmpty {
                    group("Done") {
                        VStack(spacing: 2) {
                            ForEach(doneItems) { item in
                                DoneRow(item: item, onOpen: { open(item) })
                                    .transition(.opacity)
                            }
                        }
                    }
                }

                if nothingVisible {
                    EmptyState(symbol: "tray", title: "Nothing here", line: "Nothing matches this filter yet.")
                }
            }
        }
    }

    // MARK: - Groups

    private func group<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHead(title: title)
            content()
        }
    }

    private var approvalItems: [ZInboxItem] { store.inbox.filter { $0.kind == .approval } }
    private var runningItems: [ZInboxItem] { store.inbox.filter { $0.kind == .running } }
    private var noticedItems: [ZInboxItem] { store.inbox.filter { $0.kind == .noticed } }
    private var doneItems: [ZInboxItem] { store.inbox.filter { $0.kind == .done } }

    private var nothingVisible: Bool {
        switch filter {
        case .all: return approvalItems.isEmpty && runningItems.isEmpty && noticedItems.isEmpty && doneItems.isEmpty
        case .needsYou: return approvalItems.isEmpty
        case .done: return doneItems.isEmpty
        case .noticed: return noticedItems.isEmpty
        }
    }

    // MARK: - Actions

    private func open(_ item: ZInboxItem) {
        guard let route = item.route else { return }
        ZahirNav.open(route)
    }

    private func approve(_ item: ZInboxItem) {
        guard let index = store.inbox.firstIndex(where: { $0.id == item.id }) else { return }
        withAnimation(Motion.settle) { store.inbox[index].kind = .done }
        let id = item.id
        store.toast("Approved", undo: {
            guard let i = ZahirStore.shared.inbox.firstIndex(where: { $0.id == id }) else { return }
            withAnimation(Motion.settle) { ZahirStore.shared.inbox[i].kind = .approval }
        })
    }

    private func approveAll() {
        let ids = approvalItems.map(\.id)
        guard !ids.isEmpty else { return }
        withAnimation(Motion.settle) {
            for i in store.inbox.indices where ids.contains(store.inbox[i].id) {
                store.inbox[i].kind = .done
            }
        }
        store.toast("\(ids.count) approved", undo: {
            withAnimation(Motion.settle) {
                for i in ZahirStore.shared.inbox.indices where ids.contains(ZahirStore.shared.inbox[i].id) {
                    ZahirStore.shared.inbox[i].kind = .approval
                }
            }
        })
    }

    /// Named states for Snapshot: each is rendered to a PNG for review.
    @MainActor static var snapshots: [(String, AnyView)] {
        [("inbox-1-all", AnyView(InboxSurface().frame(width: 1180, height: 740)))]
    }
}

// MARK: - Needs you

private struct ApprovalCard: View {
    let item: ZInboxItem
    let onApprove: () -> Void
    let onChange: () -> Void
    let onOpen: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 18) {
            ZStack {
                if item.image != nil { Shot(name: item.image) } else { Palette.wash }
            }
            .frame(width: 92, height: 92)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Palette.hairline, lineWidth: 1))

            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Palette.ink)
                    Text(item.line)
                        .font(.system(size: 13))
                        .foregroundStyle(Palette.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                HStack(spacing: 8) {
                    Chip(text: "Approve", action: onApprove)
                    Chip(text: "Change", action: onChange)
                    Chip(text: "Open", action: onOpen)
                    Spacer(minLength: 4)
                    Text(item.time).font(.system(size: 12)).foregroundStyle(Palette.muted)
                }
            }
        }
        .zCard(radius: 20)
    }
}

// MARK: - Working

private struct RunningRow: View {
    let item: ZInboxItem
    let onOpen: () -> Void
    @State private var over = false

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                if item.image != nil { Shot(name: item.image) } else { Palette.wash }
            }
            .frame(width: 52, height: 52)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 8) {
                Text(item.title).font(.system(size: 14, weight: .medium)).foregroundStyle(Palette.ink)
                Text(item.line).font(.system(size: 12)).foregroundStyle(Palette.muted)
                RunningBar()
            }
            Spacer(minLength: 8)
            Text(item.time).font(.system(size: 12)).foregroundStyle(Palette.muted)
        }
        .zCard(radius: 18)
        .onHover { hovering in withAnimation(Motion.quick) { over = hovering } }
        .onTapGesture(perform: onOpen)
    }
}

/// A quiet line that fills, not a spinner: Figaro is still on it.
private struct RunningBar: View {
    @State private var slid = false

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Palette.hairline)
                Capsule()
                    .fill(Palette.ink)
                    .frame(width: geo.size.width * 0.3)
                    .offset(x: slid ? geo.size.width * 0.7 : 0)
            }
        }
        .frame(height: 3)
        .clipShape(Capsule())
        .onAppear {
            guard !Snapshot.running else { return }
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) { slid = true }
        }
    }
}

// MARK: - Figaro noticed

private struct NoticedRow: View {
    let item: ZInboxItem
    let onAct: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "lightbulb")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Palette.ink)
                .frame(width: 30, height: 30)
                .background(Circle().fill(Palette.wash))

            VStack(alignment: .leading, spacing: 3) {
                Text(item.title).font(.system(size: 14, weight: .medium)).foregroundStyle(Palette.ink)
                Text(item.line)
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            Chip(text: "Act on it", action: onAct)
            Text(item.time).font(.system(size: 12)).foregroundStyle(Palette.muted)
        }
        .zCard(radius: 16, padding: 14, shadow: false)
    }
}

// MARK: - Done

private struct DoneRow: View {
    let item: ZInboxItem
    let onOpen: () -> Void
    @State private var over = false

    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: 12) {
                ZStack {
                    if item.image != nil { Shot(name: item.image) } else { Palette.wash }
                }
                .frame(width: 30, height: 30)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 1) {
                    Text(item.title).font(.system(size: 13)).foregroundStyle(Palette.muted).lineLimit(1)
                    Text(item.line).font(.system(size: 11)).foregroundStyle(Palette.faint).lineLimit(1)
                }
                Spacer(minLength: 8)
                Text(item.time).font(.system(size: 11)).foregroundStyle(Palette.muted)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 8)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(over ? Palette.hover : .clear))
        }
        .buttonStyle(.plain)
        .onHover { hovering in withAnimation(Motion.quick) { over = hovering } }
    }
}
