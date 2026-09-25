import SwiftUI
import UniformTypeIdentifiers

// The calendar: where everything Figaro and you have made actually goes
// out. A week of days, a post as a small card on each, and nothing leaves
// draft without a look first — Approve is the only door out of "review".
// Cards drag between days like paper on a table; Figaro can lay out a whole
// next week in one pass, but always as drafts, never as live posts.

enum CalendarMode: String, CaseIterable, Hashable { case week, month }

struct CalendarSurface: View {
    @ObservedObject var store = ZahirStore.shared

    @State private var mode: CalendarMode
    @State private var weekOffset: Int
    @State private var channelFilter: String?
    @State private var selectedPostID: UUID?
    @State private var dragOverDay: Int?
    @State private var planning = false
    @State private var captions: [UUID: String] = [:]
    @State private var planTask: Task<Void, Never>?

    private let initialSelectDay: Int?
    private let initialSelectChannel: String?

    /// Init params for Snapshot: the view mode, which week, and a post to
    /// preselect by day + channel (resolved once the store is reachable,
    /// in `onAppear`, rather than here — `store` isn't safe to read yet).
    init(mode: CalendarMode = .week, weekOffset: Int = 0, selectDay: Int? = nil, selectChannel: String? = nil) {
        _mode = State(initialValue: mode)
        _weekOffset = State(initialValue: weekOffset)
        initialSelectDay = selectDay
        initialSelectChannel = selectChannel
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
        .onAppear(perform: applyInitialSelection)
        .onDisappear { planTask?.cancel() }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            filterRow
            if !reviewPosts.isEmpty {
                approvalsStrip
            }
            HStack(alignment: .top, spacing: 20) {
                gridArea
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                if let post = selectedPost {
                    Rectangle().fill(Palette.hairline).frame(width: 1)
                    DetailPanel(
                        post: post,
                        dayLabel: dayLabel(for: post.day),
                        symbol: symbol(for: post.channel),
                        caption: captionBinding(for: post),
                        onSetTime: { setTime(post, $0) },
                        onApprove: { approve(post) },
                        onChange: { requestChange(post) },
                        onUnschedule: { unschedule(post) },
                        onClose: { withAnimation(Motion.settle) { selectedPostID = nil } }
                    )
                    .frame(width: 280, alignment: .leading)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
        }
        .padding(.horizontal, 32)
        .padding(.top, 24)
        .padding(.bottom, 24)
        .animation(Motion.settle, value: selectedPostID)
    }

    private func applyInitialSelection() {
        guard selectedPostID == nil, initialSelectDay != nil || initialSelectChannel != nil else { return }
        selectedPostID = store.posts.first { post in
            (initialSelectDay == nil || post.day == initialSelectDay)
                && (initialSelectChannel == nil || post.channel == initialSelectChannel)
        }?.id
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Calendar")
                    .font(.system(size: 28, weight: .semibold))
                    .tracking(-0.5)
                    .foregroundStyle(Palette.ink)
                Text(headerLine)
                    .font(.system(size: 14))
                    .foregroundStyle(Palette.muted)
            }
            Spacer(minLength: 0)
            HStack(spacing: 8) {
                HStack(spacing: 2) {
                    Choice(text: "Week", on: mode == .week) { withAnimation(Motion.settle) { mode = .week } }
                    Choice(text: "Month", on: mode == .month) { withAnimation(Motion.settle) { mode = .month } }
                }
                HStack(spacing: 4) {
                    IconButton(symbol: "chevron.left", help: "Previous week") {
                        withAnimation(Motion.settle) { weekOffset -= 1 }
                    }
                    Chip(text: weekLabel) { withAnimation(Motion.settle) { weekOffset = 0 } }
                    IconButton(symbol: "chevron.right", help: "Next week") {
                        withAnimation(Motion.settle) { weekOffset += 1 }
                    }
                }
                PrimaryButton(title: "Plan next week", symbol: "sparkle", action: planNextWeek)
            }
        }
    }

    private var headerLine: String {
        let channels = Set(store.posts.map(\.channel)).count
        let waiting = reviewPosts.count
        return "\(store.posts.count) posts across \(channels) channels · \(waiting) waiting for your OK"
    }

    private var weekLabel: String {
        switch weekOffset {
        case 0: "This week"
        case 1: "Next week"
        case -1: "Last week"
        default: weekOffset > 0 ? "In \(weekOffset) weeks" : "\(-weekOffset) weeks ago"
        }
    }

    private var filterRow: some View {
        Flow(spacing: 8, line: 8) {
            Choice(text: "All", on: channelFilter == nil) {
                withAnimation(Motion.quick) { channelFilter = nil }
            }
            ForEach(store.brand.channels, id: \.self) { channel in
                Choice(text: channel, on: channelFilter == channel, symbol: symbol(for: channel)) {
                    withAnimation(Motion.quick) { channelFilter = (channelFilter == channel) ? nil : channel }
                }
            }
        }
    }

    // MARK: - Approvals

    private var reviewPosts: [ZPost] { store.posts.filter { $0.status == .review } }

    private var approvalsStrip: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHead(title: "Needs your OK", line: "\(reviewPosts.count) waiting on you")
            Flow(spacing: 12, line: 12) {
                ForEach(reviewPosts) { post in
                    ApprovalCard(
                        post: post,
                        symbol: symbol(for: post.channel),
                        approve: { approve(post) },
                        change: { withAnimation(Motion.settle) { selectedPostID = post.id } }
                    )
                    .transition(.opacity.combined(with: .scale(scale: 0.94)))
                }
            }
        }
    }

    // MARK: - Grid

    private var gridArea: some View {
        Group {
            switch mode {
            case .week: weekGrid
            case .month: monthGrid
            }
        }
    }

    private var weekGrid: some View {
        HStack(alignment: .top, spacing: 8) {
            ForEach(displayedWeekDays, id: \.self) { day in
                DayColumn(
                    dayName: Self.dayNames[dayIndex(day)],
                    dayNumber: dayNumber(for: day),
                    isToday: isToday(day),
                    posts: posts(forDay: day),
                    showShimmer: planning && posts(forDay: day).isEmpty,
                    dragOver: dragOverDay == day,
                    symbolFor: symbol(for:),
                    onSelect: { id in withAnimation(Motion.settle) { selectedPostID = id } },
                    onDropPost: { movePost($0, to: day) },
                    onDragTargeted: { over in dragOverDay = over ? day : (dragOverDay == day ? nil : dragOverDay) }
                )
            }
        }
    }

    private var displayedWeekDays: [Int] { (0..<7).map { weekOffset * 7 + $0 } }

    private var monthGrid: some View {
        VStack(alignment: .leading, spacing: 6) {
            monthHeaderRow
            ForEach(0..<5, id: \.self) { week in
                monthWeekRow(week)
            }
        }
    }

    private var monthHeaderRow: some View {
        HStack(spacing: 6) {
            ForEach(Self.dayNames, id: \.self) { name in
                Text(name)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Palette.muted)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private func monthWeekRow(_ week: Int) -> some View {
        HStack(spacing: 6) {
            ForEach(0..<7, id: \.self) { column in
                let day = weekOffset * 7 + week * 7 + column
                MonthCell(
                    dayNumber: dayNumber(for: day),
                    isToday: isToday(day),
                    posts: posts(forDay: day),
                    onSelect: { id in withAnimation(Motion.settle) { selectedPostID = id } }
                )
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func posts(forDay day: Int) -> [ZPost] {
        store.posts
            .filter { $0.day == day && (channelFilter == nil || $0.channel == channelFilter) }
            .sorted { minutes($0.time) < minutes($1.time) }
    }

    private func minutes(_ time: String) -> Int {
        if time.lowercased() == "morning" { return 8 * 60 }
        let parts = time.split(separator: ":")
        guard parts.count == 2, let h = Int(parts[0]), let m = Int(parts[1]) else { return 0 }
        return h * 60 + m
    }

    // MARK: - Dates

    private static let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .current
        return cal
    }()

    private static let mondayOfThisWeek: Date = {
        let today = calendar.startOfDay(for: Date())
        let weekday = calendar.component(.weekday, from: today) // 1 = Sun ... 7 = Sat
        let fromMonday = (weekday + 5) % 7
        return calendar.date(byAdding: .day, value: -fromMonday, to: today) ?? today
    }()

    private static let dayNames = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    private static let fullDayNames = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]

    private func dayIndex(_ absoluteDay: Int) -> Int { ((absoluteDay % 7) + 7) % 7 }

    private func date(for absoluteDay: Int) -> Date {
        Self.calendar.date(byAdding: .day, value: absoluteDay, to: Self.mondayOfThisWeek) ?? Self.mondayOfThisWeek
    }

    private func dayNumber(for absoluteDay: Int) -> Int {
        Self.calendar.component(.day, from: date(for: absoluteDay))
    }

    private func isToday(_ absoluteDay: Int) -> Bool {
        Self.calendar.isDate(date(for: absoluteDay), inSameDayAs: Date())
    }

    private func dayLabel(for absoluteDay: Int) -> String { Self.fullDayNames[dayIndex(absoluteDay)] }

    // MARK: - Actions

    private var selectedPost: ZPost? {
        guard let selectedPostID else { return nil }
        return store.posts.first { $0.id == selectedPostID }
    }

    private func movePost(_ id: UUID, to day: Int) {
        guard let i = store.posts.firstIndex(where: { $0.id == id }) else { return }
        let from = store.posts[i].day
        guard from != day else { return }
        withAnimation(Motion.settle) { store.posts[i].day = day }
        store.toast("Moved to \(dayLabel(for: day))", undo: { [weak store] in
            guard let j = store?.posts.firstIndex(where: { $0.id == id }) else { return }
            store?.posts[j].day = from
        })
    }

    private func setTime(_ post: ZPost, _ time: String) {
        guard let i = store.posts.firstIndex(where: { $0.id == post.id }) else { return }
        withAnimation(Motion.quick) { store.posts[i].time = time }
    }

    private func approve(_ post: ZPost) {
        guard let i = store.posts.firstIndex(where: { $0.id == post.id }) else { return }
        withAnimation(Motion.settle) { store.posts[i].status = .scheduled }
        store.toast("Approved for \(post.time)")
    }

    private func unschedule(_ post: ZPost) {
        guard let i = store.posts.firstIndex(where: { $0.id == post.id }) else { return }
        let was = store.posts[i].status
        withAnimation(Motion.settle) { store.posts[i].status = .draft }
        store.toast("Unscheduled", undo: { [weak store] in
            guard let j = store?.posts.firstIndex(where: { $0.id == post.id }) else { return }
            store?.posts[j].status = was
        })
    }

    private func requestChange(_ post: ZPost) {
        store.toast("Figaro is trying a different version.")
    }

    private func captionBinding(for post: ZPost) -> Binding<String> {
        Binding(
            get: { captions[post.id] ?? post.title },
            set: { captions[post.id] = $0 }
        )
    }

    private func symbol(for channel: String) -> String {
        switch channel {
        case "Instagram": "camera"
        case "TikTok": "music.note"
        case "LinkedIn": "briefcase"
        case "Meta Ads": "megaphone"
        case "YouTube": "play.rectangle"
        default: "number"
        }
    }

    // MARK: - Plan next week

    private static let planPool: [(image: String, title: String)] = [
        ("chill", "Same slow, new week."),
        ("energy", "What the 3pm dip needs."),
        ("focus", "Nothing added, nothing to hide."),
    ]

    private func planNextWeek() {
        planTask?.cancel()
        withAnimation(Motion.settle) {
            mode = .week
            weekOffset = 1
            planning = true
        }
        planTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 750_000_000)
            guard !Task.isCancelled else { return }
            let range = 7...13
            let occupied = Set(store.posts.filter { range.contains($0.day) }.map(\.day))
            let openDays = range.filter { !occupied.contains($0) }
            let picks = Array(openDays.prefix(3))
            let channels = store.brand.channels.isEmpty ? ["Instagram"] : store.brand.channels
            let times = ["9:00", "12:00", "18:30"]
            for (i, day) in picks.enumerated() {
                let pick = Self.planPool[i % Self.planPool.count]
                let post = ZPost(
                    day: day, time: times[i % times.count], channel: channels[i % channels.count],
                    title: pick.title, image: pick.image, status: .draft
                )
                withAnimation(Motion.settle) { store.posts.append(post) }
            }
            withAnimation(Motion.settle) { planning = false }
            store.toast(picks.isEmpty ? "Next week is already full." : "Figaro planned \(picks.count) posts for next week.")
        }
    }

    /// Named states for Snapshot: each is rendered to a PNG for review.
    @MainActor static var snapshots: [(String, AnyView)] {
        [
            ("calendar-1-week", AnyView(CalendarSurface().frame(width: 1180, height: 740))),
            ("calendar-2-detail", AnyView(CalendarSurface(selectDay: 1, selectChannel: "TikTok").frame(width: 1180, height: 740))),
        ]
    }
}

// MARK: - Snapshot-safe drag and drop

private extension View {
    /// `ImageRenderer` — what Snapshot uses to make its PNGs — draws
    /// `.onDrag`/`.onDrop` as a solid yellow placeholder instead of the view
    /// underneath. Skip attaching them while a snapshot is being taken, so
    /// the card renders as itself.
    @ViewBuilder
    func zDraggable(_ id: UUID) -> some View {
        if Snapshot.running {
            self
        } else {
            self.onDrag { NSItemProvider(object: id.uuidString as NSString) }
        }
    }

    @ViewBuilder
    func zDroppable(isTargeted: Binding<Bool>, perform: @escaping ([NSItemProvider]) -> Bool) -> some View {
        if Snapshot.running {
            self
        } else {
            self.onDrop(of: [.plainText], isTargeted: isTargeted, perform: perform)
        }
    }
}

// MARK: - Day column

private struct DayColumn: View {
    let dayName: String
    let dayNumber: Int
    let isToday: Bool
    let posts: [ZPost]
    let showShimmer: Bool
    let dragOver: Bool
    let symbolFor: (String) -> String
    let onSelect: (UUID) -> Void
    let onDropPost: (UUID) -> Void
    let onDragTargeted: (Bool) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 5) {
                Text(dayName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                Text("\(dayNumber)")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(Palette.muted)
                if isToday {
                    Circle().fill(Palette.ink).frame(width: 5, height: 5)
                }
                Spacer(minLength: 0)
            }
            VStack(spacing: 8) {
                ForEach(posts) { post in
                    PostCard(post: post, symbol: symbolFor(post.channel)) { onSelect(post.id) }
                        .zDraggable(post.id)
                }
                if showShimmer {
                    PlanningShimmer()
                }
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, minHeight: 140, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(dragOver ? Palette.wash : .clear))
        .contentShape(Rectangle())
        .zDroppable(isTargeted: Binding(get: { dragOver }, set: onDragTargeted)) { providers in
            guard let provider = providers.first else { return false }
            _ = provider.loadObject(ofClass: String.self) { value, _ in
                guard let value, let uuid = UUID(uuidString: value) else { return }
                DispatchQueue.main.async { onDropPost(uuid) }
            }
            return true
        }
    }
}

private struct PlanningShimmer: View {
    @State private var pulse = false

    var body: some View {
        VStack(spacing: 6) {
            FigaroMark(size: 18)
            Text("Figaro is planning")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Palette.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Palette.wash))
        .opacity(pulse ? 0.45 : 1)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.55).repeatForever(autoreverses: true)) { pulse = true }
        }
    }
}

// MARK: - Post card

private struct PostCard: View {
    let post: ZPost
    let symbol: String
    let onSelect: () -> Void
    @State private var over = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Shot(name: post.image)
                .frame(height: 56)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            HStack(spacing: 6) {
                Text(post.time)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(Palette.muted)
                Spacer(minLength: 4)
                Image(systemName: symbol)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(Palette.ink.opacity(0.7))
                    .frame(width: 18, height: 18)
                    .background(Circle().fill(Palette.wash))
                    .help(post.channel)
            }
            Text(post.title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Palette.ink)
                .lineLimit(2)
                .truncationMode(.tail)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            StatusBadge(status: post.status)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Palette.ground))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Palette.hairline, lineWidth: 1))
        .shadow(color: .black.opacity(over ? 0.12 : 0.05), radius: over ? 14 : 8, y: over ? 6 : 3)
        .offset(y: over ? -2 : 0)
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
        .onHover { hovering in withAnimation(Motion.quick) { over = hovering } }
    }
}

private struct StatusBadge: View {
    let status: ZStatus

    var body: some View {
        switch status {
        case .draft:
            Tag(text: "Draft")
        case .review:
            NeedsOKTag()
        case .approved:
            Tag(text: "OK", symbol: "checkmark", strong: true)
        case .scheduled:
            Tag(text: "Set", symbol: "clock", strong: true)
        case .live:
            HStack(spacing: 4) {
                Circle().fill(Palette.ink).frame(width: 6, height: 6)
                Text("Live").font(.system(size: 11, weight: .medium)).foregroundStyle(Palette.ink)
            }
            .padding(.horizontal, 8)
            .frame(height: 22)
            .background(Capsule().fill(Palette.wash))
        }
    }
}

/// Visible without colour: an outlined pill, not a filled one — the one
/// status that still needs a person before it moves.
private struct NeedsOKTag: View {
    var body: some View {
        Text("Needs OK")
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(Palette.ink)
            .padding(.horizontal, 8)
            .frame(height: 22)
            .overlay(Capsule().strokeBorder(Palette.ink, lineWidth: 1))
    }
}

// MARK: - Approval card

private struct ApprovalCard: View {
    let post: ZPost
    let symbol: String
    let approve: () -> Void
    let change: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Shot(name: post.image)
                .frame(width: 36, height: 36)
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(post.title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                Text("\(post.channel) · \(post.time)")
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.muted)
                    .lineLimit(1)
            }
            .frame(maxWidth: 150, alignment: .leading)
            HStack(spacing: 6) {
                Chip(text: "Approve", action: approve).fixedSize()
                Chip(text: "Change", action: change).fixedSize()
            }
        }
        .zCard(radius: 14, padding: 10, shadow: false)
    }
}

// MARK: - Month cell

private struct MonthCell: View {
    let dayNumber: Int
    let isToday: Bool
    let posts: [ZPost]
    let onSelect: (UUID) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 3) {
                Text("\(dayNumber)")
                    .font(.system(size: 11, weight: isToday ? .semibold : .regular))
                    .foregroundStyle(isToday ? Palette.ink : Palette.muted)
                if isToday {
                    Circle().fill(Palette.ink).frame(width: 4, height: 4)
                }
                Spacer(minLength: 0)
            }
            HStack(spacing: 3) {
                ForEach(posts.prefix(3)) { post in
                    Circle().fill(Palette.ink.opacity(0.55)).frame(width: 5, height: 5)
                        .id(post.id)
                }
                if posts.count > 3 {
                    Text("+\(posts.count - 3)").font(.system(size: 9)).foregroundStyle(Palette.muted)
                }
                Spacer(minLength: 0)
            }
        }
        .padding(6)
        .frame(height: 46, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Palette.wash))
        .contentShape(Rectangle())
        .onTapGesture { if let first = posts.first { onSelect(first.id) } }
    }
}

// MARK: - Detail panel

private struct DetailPanel: View {
    let post: ZPost
    let dayLabel: String
    let symbol: String
    @Binding var caption: String
    let onSetTime: (String) -> Void
    let onApprove: () -> Void
    let onChange: () -> Void
    let onUnschedule: () -> Void
    let onClose: () -> Void

    private static let timeOptions = ["morning", "9:00", "12:00", "18:30"]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Post")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Palette.muted)
                Spacer(minLength: 8)
                IconButton(symbol: "xmark", help: "Close", action: onClose)
            }
            .padding(.bottom, 8)

            Shot(name: post.image)
                .frame(height: 100)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .padding(.bottom, 10)

            Text(post.title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Palette.ink)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 6)

            HStack(spacing: 8) {
                Tag(text: post.channel, symbol: symbol, strong: true)
                Tag(text: "\(dayLabel) \(post.time)", symbol: "clock")
            }
            .padding(.bottom, 10)

            SectionHead(title: "Time").padding(.bottom, 6)
            Flow(spacing: 8, line: 8) {
                ForEach(Self.timeOptions, id: \.self) { option in
                    Choice(text: option, on: post.time == option) { onSetTime(option) }
                }
            }
            .padding(.bottom, 10)

            SectionHead(title: "Caption").padding(.bottom, 6)
            captionField
                .padding(.bottom, 10)

            HStack(spacing: 8) {
                if post.status == .review {
                    Chip(text: "Approve", action: onApprove)
                }
                Chip(text: "Change", action: onChange)
                if post.status == .scheduled || post.status == .approved || post.status == .live {
                    Chip(text: "Unschedule", action: onUnschedule)
                }
            }
        }
        .padding(16)
        .frame(width: 280, alignment: .leading)
    }

    private var captionField: some View {
        Group {
            if Snapshot.running {
                Text(caption)
                    .foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineLimit(2)
            } else {
                TextField("Caption", text: $caption, axis: .vertical)
                    .textFieldStyle(.plain)
                    .foregroundStyle(Palette.ink)
                    .lineLimit(2...4)
            }
        }
        .font(.system(size: 12))
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Palette.wash))
    }
}
