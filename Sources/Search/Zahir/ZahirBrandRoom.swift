import SwiftUI

// The brand kit Figaro won't break: colours, voice, the lineup, who it's for,
// and the rules that keep everything it makes on-brand. Canva's brand kit,
// but enforced rather than just stored — see "Rules Figaro keeps" and
// "Stopped this week" below.

struct BrandRoom: View {
    @ObservedObject var store = ZahirStore.shared
    private let fixedBrandID: String?

    /// `brandID` pins the room to one brand for Snapshot, reading it
    /// directly rather than touching the shared store.
    init(brandID: String? = nil) {
        fixedBrandID = brandID
    }

    private var activeBrandID: String { fixedBrandID ?? store.brandID }
    private var brand: ZBrand { store.brands.first { $0.id == activeBrandID } ?? store.brands[0] }

    var body: some View {
        SurfacePage(title: brand.name, line: "\(brand.site) · \(brand.promise)") {
            ForEach(store.brands) { candidate in
                Choice(text: candidate.name, on: candidate.id == activeBrandID) {
                    withAnimation(Motion.settle) { store.brandID = candidate.id }
                }
            }
            Chip(text: "Re-read site") {
                store.toast("Figaro re-read \(brand.site). Nothing changed.")
            }
            PrimaryButton(title: "Add a product") {
                store.toast("Figaro is drafting a new product for \(brand.name).")
            }
        } content: {
            VStack(alignment: .leading, spacing: 36) {
                HStack(alignment: .top, spacing: 24) {
                    LookSection(brand: brand).frame(maxWidth: .infinity, alignment: .leading)
                    VoiceSection(brand: brand).frame(maxWidth: .infinity, alignment: .leading)
                }
                ProductsSection(store: store, brand: brand)
                HStack(alignment: .top, spacing: 24) {
                    AudiencesSection(brand: brand).frame(maxWidth: .infinity, alignment: .leading)
                    RulesSection(store: store, brand: brand).frame(maxWidth: .infinity, alignment: .leading)
                }
                StoppedSection(brand: brand)
            }
        }
    }

    /// Named states for Snapshot: each is rendered to a PNG for review.
    @MainActor static var snapshots: [(String, AnyView)] {
        [
            ("brand-1-palmix", AnyView(BrandRoom(brandID: "palmix"))),
            ("brand-2-tidewater", AnyView(BrandRoom(brandID: "tidewater"))),
        ]
    }
}

// MARK: - Look

private struct LookSection: View {
    let brand: ZBrand

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            SectionHead(title: "Look")
            HStack(alignment: .center, spacing: 16) {
                Avatar(letter: brand.letter, size: 72, tint: brand.palette.first?.color ?? Palette.ink)
                VStack(alignment: .leading, spacing: 4) {
                    Text(brand.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Palette.ink)
                    Text(brand.typeface)
                        .font(.system(size: 13))
                        .foregroundStyle(Palette.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            HStack(spacing: 14) {
                ForEach(brand.palette) { swatch in
                    SwatchChip(swatch: swatch, size: 54)
                }
            }
        }
        .zCard()
    }
}

// MARK: - Voice

private struct VoiceSection: View {
    let brand: ZBrand

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            SectionHead(title: "Voice")
            Flow(spacing: 8, line: 8) {
                ForEach(brand.voice, id: \.self) { word in
                    Tag(text: word, strong: true)
                }
            }
            HStack(alignment: .top, spacing: 24) {
                VoiceList(label: "Say", lines: brand.voiceDo, muted: false)
                    .frame(maxWidth: .infinity, alignment: .leading)
                VoiceList(label: "Don't say", lines: brand.voiceDont, muted: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .zCard()
    }
}

private struct VoiceList: View {
    let label: String
    let lines: [String]
    let muted: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(muted ? Palette.muted : Palette.ink)
            ForEach(lines, id: \.self) { line in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: muted ? "xmark" : "checkmark")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Palette.muted)
                        .padding(.top, 3)
                    Text(line)
                        .strikethrough(muted, color: Palette.muted)
                        .font(.system(size: 13))
                        .foregroundStyle(muted ? Palette.muted : Palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

// MARK: - Products

private struct ProductsSection: View {
    let store: ZahirStore
    let brand: ZBrand

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 18), count: 6)

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            SectionHead(title: "Products", line: brand.products.isEmpty ? nil : "\(brand.products.count) in the lineup")
            if brand.products.isEmpty {
                EmptyState(
                    symbol: "shippingbox",
                    title: "No products yet",
                    line: "Figaro hasn't read the shop at \(brand.site).",
                    action: ("Let Figaro read \(brand.site)", {
                        store.toast("Figaro is reading \(brand.site).")
                    })
                )
                .zCard()
            } else {
                LazyVGrid(columns: columns, alignment: .leading, spacing: 24) {
                    ForEach(Array(brand.products.enumerated()), id: \.element.id) { index, product in
                        Dealt(index: index) {
                            ProductCard(product: product) {
                                store.toast("Opened \(product.name).")
                            }
                        }
                    }
                }
            }
        }
    }
}

private struct ProductCard: View {
    let product: ZProduct
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Color.clear
                .aspectRatio(4 / 5, contentMode: .fit)
                .overlay(Shot(name: product.image))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(product.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                Text(product.flavour)
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.muted)
                Text(product.line)
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.muted)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .onTapGesture(perform: action)
    }
}

// MARK: - Audiences

private struct AudiencesSection: View {
    let brand: ZBrand

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            SectionHead(title: "Audiences")
            if brand.audiences.isEmpty {
                EmptyState(symbol: "person.2", title: "No audiences yet", line: "Figaro hasn't found who \(brand.name) speaks to.")
                    .zCard()
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(brand.audiences) { audience in
                        VStack(alignment: .leading, spacing: 0) {
                            Rectangle().fill(Palette.hairline).frame(height: 1)
                            AudienceRow(audience: audience).padding(.vertical, 14)
                        }
                    }
                }
                .zCard()
            }
        }
    }
}

private struct AudienceRow: View {
    let audience: ZAudience

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 5) {
                Text(audience.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                Text(audience.line)
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.muted)
                    .fixedSize(horizontal: false, vertical: true)
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Palette.wash)
                        Capsule().fill(Palette.ink)
                            .frame(width: geo.size.width * CGFloat(audience.share) / 100)
                    }
                }
                .frame(height: 5)
                .padding(.top, 3)
            }
            Spacer(minLength: 12)
            Text("\(audience.share)%")
                .font(.system(size: 15, weight: .semibold).monospacedDigit())
                .foregroundStyle(Palette.ink)
        }
    }
}

// MARK: - Rules

private struct RulesSection: View {
    let store: ZahirStore
    let brand: ZBrand

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            SectionHead(title: "Rules Figaro keeps", line: "Every image, ad and post checks against these first.")
            if brand.rules.isEmpty {
                EmptyState(symbol: "checklist", title: "No rules yet", line: "Figaro hasn't learned \(brand.name)'s rules.")
                    .zCard()
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(brand.rules) { rule in
                        VStack(alignment: .leading, spacing: 0) {
                            Rectangle().fill(Palette.hairline).frame(height: 1)
                            RuleRow(store: store, brandID: brand.id, rule: rule).padding(.vertical, 12)
                        }
                    }
                }
                .zCard()
            }
        }
    }
}

private struct RuleRow: View {
    let store: ZahirStore
    let brandID: String
    let rule: ZRule

    var body: some View {
        HStack(spacing: 14) {
            Text(rule.text)
                .font(.system(size: 14))
                .foregroundStyle(rule.on ? Palette.ink : Palette.muted)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 12)
            RuleSwitch(on: rule.on, action: toggle)
        }
    }

    private func toggle() {
        guard let bi = store.brands.firstIndex(where: { $0.id == brandID }),
              let ri = store.brands[bi].rules.firstIndex(where: { $0.id == rule.id }) else { return }
        let was = store.brands[bi].rules[ri].on
        withAnimation(Motion.quick) { store.brands[bi].rules[ri].on = !was }
        let text = rule.text
        store.toast(was ? "Turned off: \(text)" : "Turned on: \(text)", undo: {
            guard let bi2 = store.brands.firstIndex(where: { $0.id == brandID }),
                  let ri2 = store.brands[bi2].rules.firstIndex(where: { $0.id == rule.id }) else { return }
            store.brands[bi2].rules[ri2].on = was
        })
    }
}

/// A capsule with a knob: ink when on, wash when off.
private struct RuleSwitch: View {
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

// MARK: - Stopped this week

private struct StoppedSection: View {
    let brand: ZBrand

    private var items: [(image: String, reason: String)] {
        let pool: [(String, String)] = [
            ("energy", "Headline had 11 words"),
            ("glow", "Logo on a busy background"),
            ("focus", "Glossy skin, not a real photo"),
        ]
        let images = brand.products.map(\.image)
        return pool.enumerated().map { index, pair in
            let image = images.isEmpty ? pair.0 : images[index % images.count]
            return (image, pair.1)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            SectionHead(title: "Stopped this week", line: "Caught by the rules above before anything went out.")
            HStack(spacing: 16) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    StoppedCard(image: item.image, reason: item.reason)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
}

private struct StoppedCard: View {
    let image: String
    let reason: String

    var body: some View {
        HStack(spacing: 12) {
            Shot(name: image)
                .frame(width: 48, height: 48)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                Image(systemName: "hand.raised.fill")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Palette.muted)
                Text(reason)
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .zCard(radius: 14, padding: 12)
    }
}
