import SwiftUI

// Hire Figaro: the one conversation before Figaro joins. Four short steps —
// where's your site, what Figaro finds there, how your team works, and the
// handoff — read the way the rest of Zahir reads: a title that stays put, a
// question at a time, one black pill to move forward.

struct HireFigaro: View {
    @ObservedObject var store = ZahirStore.shared
    @State private var step: Int
    @State private var site = "palmix.co"
    @State private var noSite = false

    init(step: Int = 0) {
        _step = State(initialValue: step)
    }

    var body: some View {
        SurfacePage(title: "Hire Figaro", line: step == 0 ? introLine : nil) {
            VStack(alignment: .leading, spacing: 32) {
                dots
                stage
            }
            .animation(Motion.settle, value: step)
        }
    }

    private var introLine: String {
        "Figaro is the marketer on your team. Give it your website and it learns your brand in about a minute."
    }

    @ViewBuilder
    private var stage: some View {
        switch step {
        case 0:
            SiteStep(site: $site, onSkip: { noSite = true; step = 2 }, onNext: { step = 1 })
                .transition(stepTransition)
        case 1:
            ReadingStep(site: site, brand: store.brand, onBack: { step = 0 }, onContinue: { step = 2 })
                .transition(stepTransition)
        case 2:
            SetupStep(onBack: { step = noSite ? 0 : 1 }, onContinue: { step = 3 })
                .transition(stepTransition)
        default:
            DoneStep(onBack: { step = 2 })
                .transition(stepTransition)
        }
    }

    private var stepTransition: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        )
    }

    private var dots: some View {
        HStack(spacing: 8) {
            ForEach(0..<4) { i in
                NumberBadge(number: i + 1, filled: i <= step)
            }
        }
    }

    /// Named states for Snapshot: each is rendered to a PNG for review.
    @MainActor static var snapshots: [(String, AnyView)] {
        [
            ("hire-1-site", AnyView(HireFigaro(step: 0).frame(width: 1180, height: 740))),
            ("hire-2-reading", AnyView(HireFigaro(step: 1).frame(width: 1180, height: 740))),
            ("hire-3-setup", AnyView(HireFigaro(step: 2).frame(width: 1180, height: 740))),
            ("hire-4-done", AnyView(HireFigaro(step: 3).frame(width: 1180, height: 740))),
        ]
    }
}

// MARK: - 1. Site

private struct SiteStep: View {
    @Binding var site: String
    let onSkip: () -> Void
    let onNext: () -> Void
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Your website")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Palette.muted)
                field
            }
            .frame(width: 420, alignment: .leading)

            HStack(spacing: 12) {
                PrimaryButton(title: "Read my site", symbol: "arrow.right", action: onNext)
                Chip(text: "I don't have a website", action: onSkip)
            }
        }
        .padding(.top, 6)
    }

    private var field: some View {
        HStack(spacing: 10) {
            Image(systemName: "globe")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Palette.muted)
            Group {
                if Snapshot.running {
                    Text(site)
                } else {
                    TextField("yoursite.com", text: $site)
                        .textFieldStyle(.plain)
                        .focused($focused)
                        .onSubmit(onNext)
                }
            }
            .font(.system(size: 15))
            .foregroundStyle(Palette.ink)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 16)
        .frame(height: 46)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Palette.wash))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Palette.hairline, lineWidth: 1))
    }
}

// MARK: - 2. Reading

private struct ReadingStep: View {
    let site: String
    let brand: ZBrand
    let onBack: () -> Void
    let onContinue: () -> Void

    private let checklist = [
        "Reading the homepage",
        "Finding your colors",
        "Learning your voice",
        "Cataloging your products",
        "Mapping your audience",
    ]

    @State private var found = Snapshot.running ? 5 : 0

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(spacing: 10) {
                IconButton(symbol: "chevron.left", help: "Back", action: onBack)
                SectionHead(title: "Reading \(site)", line: "This takes about a minute.")
            }

            HStack(alignment: .top, spacing: 40) {
                checklistColumn
                findingsColumn
            }

            if found >= checklist.count {
                PrimaryButton(title: "Looks right", symbol: "checkmark", action: onContinue)
                    .transition(.opacity)
            }
        }
        .task { await reveal() }
    }

    private func reveal() async {
        guard found < checklist.count else { return }
        for next in found..<checklist.count {
            try? await Task.sleep(nanoseconds: 700_000_000)
            if Task.isCancelled { return }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { found = next + 1 }
        }
    }

    private var checklistColumn: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(Array(checklist.enumerated()), id: \.offset) { index, text in
                HStack(spacing: 12) {
                    ZStack {
                        Circle().strokeBorder(Palette.hairline, lineWidth: 1)
                        if index < found {
                            Circle().fill(Palette.ink)
                            Image(systemName: "checkmark")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(Palette.ground)
                        } else if index == found, !Snapshot.running {
                            ProgressView().controlSize(.mini)
                        }
                    }
                    .frame(width: 20, height: 20)
                    Text(text)
                        .font(.system(size: 14))
                        .foregroundStyle(index <= found ? Palette.ink : Palette.faint)
                }
            }
        }
        .frame(width: 210, alignment: .leading)
        .padding(.top, 4)
    }

    private var findingsColumn: some View {
        VStack(alignment: .leading, spacing: 14) {
            if found > 0 { Dealt(index: 0, crooked: false) { identityCard } }
            if found > 1 { Dealt(index: 1, crooked: false) { paletteCard } }
            if found > 2 { Dealt(index: 2, crooked: false) { voiceCard } }
            if found > 3 { Dealt(index: 3, crooked: false) { productsCard } }
            if found > 4 { Dealt(index: 4, crooked: false) { audiencesCard } }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var identityCard: some View {
        HStack(spacing: 14) {
            Avatar(letter: brand.letter, size: 44)
            VStack(alignment: .leading, spacing: 3) {
                Text(brand.name).font(.system(size: 16, weight: .semibold)).foregroundStyle(Palette.ink)
                Text(brand.promise).font(.system(size: 13)).foregroundStyle(Palette.muted)
            }
        }
        .zCard(radius: 16, padding: 16)
    }

    private var paletteCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Palette").font(.system(size: 13, weight: .semibold)).foregroundStyle(Palette.ink)
            HStack(spacing: 12) {
                ForEach(brand.palette) { swatch in SwatchChip(swatch: swatch, size: 48) }
            }
        }
        .zCard(radius: 16, padding: 16)
    }

    private var voiceCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Voice").font(.system(size: 13, weight: .semibold)).foregroundStyle(Palette.ink)
            Flow(spacing: 6, line: 6) {
                ForEach(brand.voice, id: \.self) { word in Tag(text: word) }
            }
        }
        .zCard(radius: 16, padding: 16)
    }

    private var productsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Products").font(.system(size: 13, weight: .semibold)).foregroundStyle(Palette.ink)
            HStack(spacing: 10) {
                ForEach(brand.products) { product in
                    VStack(spacing: 6) {
                        Shot(name: product.image)
                            .frame(width: 52, height: 52)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        Text(product.name).font(.system(size: 11)).foregroundStyle(Palette.muted)
                    }
                }
            }
        }
        .zCard(radius: 16, padding: 16)
    }

    private var audiencesCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Audiences").font(.system(size: 13, weight: .semibold)).foregroundStyle(Palette.ink)
            ForEach(brand.audiences) { audience in
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(audience.name).font(.system(size: 13, weight: .medium)).foregroundStyle(Palette.ink)
                    Text(audience.line).font(.system(size: 12)).foregroundStyle(Palette.muted)
                    Spacer(minLength: 8)
                    Tag(text: "\(audience.share)%")
                }
            }
        }
        .zCard(radius: 16, padding: 16)
    }
}

// MARK: - 3. Setup

private struct SetupStep: View {
    @ObservedObject var store = ZahirStore.shared
    let onBack: () -> Void
    let onContinue: () -> Void

    private let channels = ["Instagram", "TikTok", "LinkedIn", "Meta Ads", "YouTube", "X"]

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            HStack(spacing: 10) {
                IconButton(symbol: "chevron.left", help: "Back", action: onBack)
                SectionHead(title: "How big is your team?")
            }
            tierRow

            SectionHead(title: "Where do you post?")
            Flow(spacing: 8, line: 8) {
                ForEach(channels, id: \.self) { channel in
                    Choice(text: channel, on: store.brand.channels.contains(channel)) {
                        toggle(channel)
                    }
                }
            }

            PrimaryButton(title: "Continue", symbol: "arrow.right", action: onContinue)
        }
    }

    private func toggle(_ channel: String) {
        var brand = store.brand
        if let i = brand.channels.firstIndex(of: channel) {
            brand.channels.remove(at: i)
        } else {
            brand.channels.append(channel)
        }
        store.brand = brand
    }

    private var tierRow: some View {
        HStack(spacing: 14) {
            ForEach(ZTier.allCases, id: \.self) { tier in
                TierCard(tier: tier, selected: store.tier == tier) {
                    store.tier = tier
                }
            }
        }
        .animation(Motion.quick, value: store.tier)
    }
}

private struct TierCard: View {
    let tier: ZTier
    let selected: Bool
    let action: () -> Void
    @State private var over = false

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: tier.symbol)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Palette.ink)
                    Spacer(minLength: 0)
                    ZStack {
                        Circle().strokeBorder(Palette.hairline, lineWidth: 1)
                        if selected {
                            Circle().fill(Palette.ink)
                            Image(systemName: "checkmark")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(Palette.ground)
                        }
                    }
                    .frame(width: 20, height: 20)
                }
                Text(tier.title).font(.system(size: 15, weight: .semibold)).foregroundStyle(Palette.ink)
                Text(tier.line)
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(18)
            .frame(width: 216, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Palette.ground))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(selected ? Palette.ink : Palette.hairline, lineWidth: selected ? 1.5 : 1)
            )
            .shadow(color: .black.opacity(over ? 0.08 : 0), radius: 20, y: 8)
        }
        .buttonStyle(.plain)
        .onHover { hovering in withAnimation(Motion.quick) { over = hovering } }
    }
}

// MARK: - 4. Done

private struct DoneStep: View {
    @ObservedObject var store = ZahirStore.shared
    let onBack: () -> Void

    private var brand: ZBrand { store.brand }

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            HStack(spacing: 10) {
                IconButton(symbol: "chevron.left", help: "Back", action: onBack)
                SectionHead(title: "Figaro is on the team.")
            }

            HStack(alignment: .top, spacing: 20) {
                Dealt(index: 0, crooked: false) { summaryCard }
                Dealt(index: 1, crooked: false) { thisWeekCard }
            }

            PrimaryButton(title: "Open Figaro", symbol: "sparkle") {
                store.hired = true
                store.toast("Figaro is on the team", symbol: "sparkle")
                ZahirNav.open(.figaro)
            }
        }
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Avatar(letter: brand.letter, size: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text(brand.name).font(.system(size: 15, weight: .semibold)).foregroundStyle(Palette.ink)
                    Text(brand.promise).font(.system(size: 12)).foregroundStyle(Palette.muted)
                }
            }
            HStack(spacing: 10) {
                ForEach(brand.palette.prefix(3)) { swatch in SwatchChip(swatch: swatch, size: 44) }
            }
            HStack(spacing: 10) {
                ForEach(brand.products.prefix(2)) { product in
                    VStack(spacing: 6) {
                        Shot(name: product.image)
                            .frame(width: 56, height: 56)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        Text(product.name).font(.system(size: 11)).foregroundStyle(Palette.muted)
                    }
                }
            }
        }
        .zCard(radius: 18, padding: 18)
        .frame(width: 300, alignment: .leading)
    }

    private var thisWeekCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("This week Figaro will")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Palette.ink)
            VStack(alignment: .leading, spacing: 14) {
                weekRow(1, "Write three ads for Energy")
                weekRow(2, "Plan next week's posts")
                weekRow(3, "Watch what Vita Coco does")
            }
        }
        .zCard(radius: 18, padding: 18)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func weekRow(_ n: Int, _ text: String) -> some View {
        HStack(spacing: 12) {
            NumberBadge(number: n)
            Text(text).font(.system(size: 14)).foregroundStyle(Palette.ink)
        }
    }
}
