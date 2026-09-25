import SwiftUI

// The one world every Zahir surface reads and writes. Whatever the image
// studio makes lands in the library, the calendar and Figaro's memory: that
// is the point of the superapp, nothing is lost between tools.
//
// Prototype: in memory, seeded with Palmix and a second brand for the agency
// setup. Nothing leaves the Mac, nothing is saved between launches.

struct ZSwatch: Identifiable, Hashable {
    var id: String { hex }
    let name: String
    let hex: String
    var color: Color { Color(hex: hex) }
}

struct ZProduct: Identifiable, Hashable {
    let id: String
    let name: String
    let flavour: String
    let image: String
    let line: String
}

struct ZAudience: Identifiable, Hashable {
    let id: String
    let name: String
    let line: String
    let share: Int
}

struct ZRule: Identifiable, Hashable {
    let id: String
    let text: String
    var on: Bool
}

struct ZBrand: Identifiable, Hashable {
    let id: String
    var name: String
    var site: String
    var promise: String
    var letter: String
    var palette: [ZSwatch]
    var typeface: String
    var voice: [String]
    var voiceDo: [String]
    var voiceDont: [String]
    var products: [ZProduct]
    var audiences: [ZAudience]
    var rules: [ZRule]
    var channels: [String]
}

enum ZAssetKind: String, CaseIterable, Hashable {
    case image, video, copy, post, layout, read

    var name: String {
        switch self {
        case .image: "Image"
        case .video: "Video"
        case .copy: "Copy"
        case .post: "Post"
        case .layout: "Layout"
        case .read: "Research"
        }
    }
    var symbol: String {
        switch self {
        case .image: "photo"
        case .video: "film"
        case .copy: "text.alignleft"
        case .post: "paperplane"
        case .layout: "rectangle.3.group"
        case .read: "magnifyingglass"
        }
    }
}

enum ZStatus: String, CaseIterable, Hashable {
    case draft, review, approved, scheduled, live

    var name: String { rawValue.prefix(1).uppercased() + rawValue.dropFirst() }
}

struct ZAsset: Identifiable, Hashable {
    let id: UUID
    var kind: ZAssetKind
    var title: String
    var image: String?
    var product: String?
    var channel: String?
    var byFigaro: Bool
    var made: String
    var status: ZStatus

    init(_ kind: ZAssetKind, _ title: String, image: String? = nil, product: String? = nil,
         channel: String? = nil, byFigaro: Bool = true, made: String = "Today", status: ZStatus = .draft) {
        id = UUID()
        self.kind = kind
        self.title = title
        self.image = image
        self.product = product
        self.channel = channel
        self.byFigaro = byFigaro
        self.made = made
        self.status = status
    }
}

/// One turn in a conversation with Figaro. Figaro's turns can carry an answer
/// (the same cards the pill shows) and the tools it used.
struct ZMessage: Identifiable {
    let id = UUID()
    let fromFigaro: Bool
    var text: String
    var answer: Answer? = nil
    var tools: [Tool] = []
    var time: String = ""
}

struct ZThread: Identifiable {
    let id: UUID
    var title: String
    var updated: String
    var messages: [ZMessage]

    init(_ title: String, updated: String, _ messages: [ZMessage]) {
        id = UUID()
        self.title = title
        self.updated = updated
        self.messages = messages
    }
}

/// Something Figaro has learned and keeps using.
struct ZMemory: Identifiable, Hashable {
    let id = UUID()
    let text: String
    let source: String
}

/// How big the team around Figaro is: the Iron Man suit, three ways.
enum ZTier: String, CaseIterable, Hashable {
    case alone, marketer, agency

    var title: String {
        switch self {
        case .alone: "It's just me"
        case .marketer: "I'm the marketer"
        case .agency: "We're a team or agency"
        }
    }
    var line: String {
        switch self {
        case .alone: "Figaro handles the basics: posts, ads, a plan each week."
        case .marketer: "Figaro does the heavy lifting; you make the calls."
        case .agency: "Figaro works across every brand you run, with approvals."
        }
    }
    var symbol: String {
        switch self {
        case .alone: "person"
        case .marketer: "person.crop.circle.badge.checkmark"
        case .agency: "person.3"
        }
    }
}

/// Something pointed at on a page and brought into Zahir: "make ours".
struct ZReference {
    let image: NSImage?
    let source: String
    let note: String
}

/// A size an ad has to exist in.
struct ZFormat: Identifiable, Hashable {
    var id: String { name }
    let name: String
    let width: Int
    let height: Int
    let channel: String

    var label: String { "\(width)×\(height)" }
    var ratio: CGFloat { CGFloat(width) / CGFloat(height) }

    static let all: [ZFormat] = [
        ZFormat(name: "Story", width: 1080, height: 1920, channel: "Instagram"),
        ZFormat(name: "Square", width: 1080, height: 1080, channel: "Instagram"),
        ZFormat(name: "Portrait", width: 1080, height: 1350, channel: "Instagram"),
        ZFormat(name: "Feed", width: 1200, height: 628, channel: "Meta Ads"),
        ZFormat(name: "TikTok", width: 1080, height: 1920, channel: "TikTok"),
        ZFormat(name: "LinkedIn", width: 1200, height: 627, channel: "LinkedIn"),
        ZFormat(name: "Thumbnail", width: 1280, height: 720, channel: "YouTube"),
        ZFormat(name: "Display", width: 300, height: 250, channel: "Web"),
    ]
}

struct ZToast: Identifiable {
    let id = UUID()
    let text: String
    var symbol = "checkmark"
    var undo: (() -> Void)? = nil
}

// MARK: - Wave 3: running marketing

/// A post on the calendar.
struct ZPost: Identifiable, Hashable {
    let id = UUID()
    var day: Int            // 0 = Monday of this week, 7 = next Monday, ...
    var time: String
    var channel: String
    var title: String
    var image: String?
    var status: ZStatus
}

/// One step of a playbook. Checkpoints wait for a person.
struct ZPlayStep: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let tool: Tool
    var checkpoint = false
    var done = false
}

/// Know-how, packaged: a chain of steps someone has proven works.
struct ZPlaybook: Identifiable, Hashable {
    let id: String
    let name: String
    let line: String
    let from: String        // who proved it: "FANDS" or "You"
    let length: String
    var steps: [ZPlayStep]
    var running = false
    var image: String?
}

/// How one piece did.
struct ZResult: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let image: String?
    let channel: String
    let spend: Int
    let clicks: Int
    let ctr: Double
    let cpa: Double
    let week: [Double]      // clicks per day, last 7 days
}

/// A competitor Figaro keeps an eye on.
struct ZCompetitor: Identifiable, Hashable {
    let id: String
    let name: String
    let site: String
    let owns: String
    let ads: Int
    let notes: [String]
    let image: String?
}

enum ZInboxKind: String, Hashable { case approval, done, running, noticed }

struct ZInboxItem: Identifiable, Hashable {
    let id = UUID()
    var kind: ZInboxKind
    var title: String
    var line: String
    var time: String
    var image: String?
    var route: ZahirRoute?
}

@MainActor
final class ZahirStore: ObservableObject {
    static let shared = ZahirStore()

    @Published var brands: [ZBrand] = [ZahirStore.palmix, ZahirStore.tidewater]
    @Published var brandID = "palmix"
    @Published var tier: ZTier = .marketer
    /// False until Figaro has been hired: the onboarding surface flips it.
    @Published var hired = true
    @Published var assets: [ZAsset] = ZahirStore.seedAssets
    @Published var threads: [ZThread] = ZahirStore.seedThreads
    @Published var threadID: UUID?
    @Published var memories: [ZMemory] = ZahirStore.seedMemories
    @Published private(set) var toasts: [ZToast] = []
    /// Brought in from a page with "make ours"; the image studio starts from it.
    @Published var reference: ZReference?
    /// The card a studio was opened with ("Open in studio" on an answer).
    @Published var handoff: Answer.Card?
    /// The sidebar's dock: folded to one line until the dots are clicked.
    @Published var dockOpen = UserDefaults.standard.bool(forKey: "zahir.dockOpen") {
        didSet { UserDefaults.standard.set(dockOpen, forKey: "zahir.dockOpen") }
    }
    @Published var posts: [ZPost] = ZahirStore.seedPosts
    @Published var playbooks: [ZPlaybook] = ZahirStore.seedPlaybooks
    @Published var results: [ZResult] = ZahirStore.seedResults
    @Published var competitors: [ZCompetitor] = ZahirStore.seedCompetitors
    @Published var inbox: [ZInboxItem] = ZahirStore.seedInbox

    var brand: ZBrand {
        get { brands.first { $0.id == brandID } ?? brands[0] }
        set {
            if let i = brands.firstIndex(where: { $0.id == newValue.id }) { brands[i] = newValue }
        }
    }

    var thread: ZThread? {
        threads.first { $0.id == threadID } ?? threads.first
    }

    // MARK: Actions

    func toast(_ text: String, symbol: String = "checkmark", undo: (() -> Void)? = nil) {
        let toast = ZToast(text: text, symbol: symbol, undo: undo)
        toasts.append(toast)
        let id = toast.id
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) { [weak self] in self?.dismiss(id) }
    }

    func dismiss(_ id: UUID) {
        toasts.removeAll { $0.id == id }
    }

    /// Keep something Figaro made: it goes to the library, and can be undone.
    func keep(_ asset: ZAsset) {
        assets.insert(asset, at: 0)
        let id = asset.id
        toast("Saved to Library", undo: { [weak self] in self?.assets.removeAll { $0.id == id } })
    }

    func remember(_ text: String, from source: String) {
        memories.insert(ZMemory(text: text, source: source), at: 0)
    }

    /// Add a turn to the open thread (or start one).
    func say(_ message: ZMessage, title: String? = nil) {
        if let id = threadID ?? threads.first?.id, let i = threads.firstIndex(where: { $0.id == id }) {
            threads[i].messages.append(message)
            threads[i].updated = "Now"
        } else {
            let thread = ZThread(title ?? message.text, updated: "Now", [message])
            threads.insert(thread, at: 0)
            threadID = thread.id
        }
    }

    func newThread() {
        let thread = ZThread("New conversation", updated: "Now", [])
        threads.insert(thread, at: 0)
        threadID = thread.id
    }

    // MARK: Seeds

    static let palmix = ZBrand(
        id: "palmix",
        name: "Palmix",
        site: "palmix.co",
        promise: "Coconut water with nothing to hide.",
        letter: "P",
        palette: [
            ZSwatch(name: "Sand", hex: "#EADBC0"),
            ZSwatch(name: "Coconut", hex: "#FBF8F2"),
            ZSwatch(name: "Palm", hex: "#2E5E3A"),
            ZSwatch(name: "Sunset", hex: "#E4572E"),
            ZSwatch(name: "Ink", hex: "#1B1A17"),
        ],
        typeface: "A soft serif for the name, a plain sans for everything else",
        voice: ["Calm", "Honest", "Sunlit", "A little dry"],
        voiceDo: ["Slow down.", "Sugar you can read on the label.", "Tastes like a day off."],
        voiceDont: ["Crush your goals.", "Superfood!!", "Hydration revolution."],
        products: [
            ZProduct(id: "chill", name: "Chill", flavour: "Pineapple", image: "chill", line: "Pineapple and coconut. The slow one."),
            ZProduct(id: "energy", name: "Energy", flavour: "Watermelon", image: "energy", line: "Watermelon and coconut, for the 3pm dip."),
            ZProduct(id: "focus", name: "Focus", flavour: "Pure coconut", image: "focus", line: "Coconut water and nothing else."),
            ZProduct(id: "fun", name: "Fun", flavour: "Strawberry", image: "fun", line: "Strawberry and coconut, for weekends."),
            ZProduct(id: "glow", name: "Glow", flavour: "Mango", image: "glow", line: "Mango and coconut, cold from the fridge."),
            ZProduct(id: "recover", name: "Recover", flavour: "Kiwi", image: "recover", line: "Kiwi and coconut, after the long day."),
        ],
        audiences: [
            ZAudience(id: "breakers", name: "The 3pm breakers", line: "Office workers who want a pause, not a buzz.", share: 42),
            ZAudience(id: "beach", name: "Beach weekenders", line: "Ages 22–34, on the coast every Saturday they can be.", share: 31),
            ZAudience(id: "label", name: "Label readers", line: "Parents and gym-goers who check the sugar first.", share: 27),
        ],
        rules: [
            ZRule(id: "logo", text: "Logo never smaller than 48 px", on: true),
            ZRule(id: "busy", text: "Never on a busy background", on: true),
            ZRule(id: "words", text: "Headlines up to 7 words", on: true),
            ZRule(id: "people", text: "Real people only, no glossy AI skin", on: true),
            ZRule(id: "gym", text: "No gym, no sweat, no 'performance'", on: false),
        ],
        channels: ["Instagram", "TikTok", "LinkedIn", "Meta Ads"]
    )

    static let tidewater = ZBrand(
        id: "tidewater",
        name: "Tidewater Surf Co.",
        site: "tidewater.surf",
        promise: "Boards shaped for cold water.",
        letter: "T",
        palette: [
            ZSwatch(name: "Kelp", hex: "#23433A"),
            ZSwatch(name: "Fog", hex: "#DDE3E1"),
            ZSwatch(name: "Buoy", hex: "#F26B38"),
        ],
        typeface: "A wide grotesk",
        voice: ["Salty", "Plain", "Local"],
        voiceDo: ["Shaped in the garage, tested at dawn."],
        voiceDont: ["Epic vibes only."],
        products: [],
        audiences: [],
        rules: [],
        channels: ["Instagram", "YouTube"]
    )

    static let seedAssets: [ZAsset] = [
        ZAsset(.image, "Your 3pm, without the crash.", image: "energy", product: "Energy", channel: "Instagram", made: "Today 9:12", status: .review),
        ZAsset(.image, "Slow is a flavour.", image: "chill", product: "Chill", channel: "Instagram", made: "Today 9:12", status: .review),
        ZAsset(.image, "Summer, bottled honestly.", image: "glow", product: "Glow", channel: "Meta Ads", made: "Today 9:13", status: .approved),
        ZAsset(.video, "Glow launch: the pop, the pour, the line", image: "glow", product: "Glow", channel: "TikTok", made: "Yesterday", status: .draft),
        ZAsset(.post, "We tested Focus on the people who make it.", image: "focus", product: "Focus", channel: "LinkedIn", made: "Yesterday", status: .scheduled),
        ZAsset(.read, "Vita Coco sells sport. Nobody owns calm.", product: nil, channel: nil, made: "Mon", status: .approved),
        ZAsset(.copy, "Twelve captions for Fun weekends", image: "fun", product: "Fun", channel: "Instagram", byFigaro: false, made: "Mon", status: .draft),
        ZAsset(.layout, "Recover, sized for every channel", image: "recover", product: "Recover", channel: "Meta Ads", made: "Sun", status: .live),
    ]


    static let seedPosts: [ZPost] = [
        ZPost(day: 0, time: "9:00", channel: "Instagram", title: "Slow is a flavour.", image: "chill", status: .live),
        ZPost(day: 1, time: "9:00", channel: "LinkedIn", title: "We tested Focus on the people who make it.", image: "focus", status: .scheduled),
        ZPost(day: 1, time: "18:30", channel: "TikTok", title: "Glow: the pop, the pour, the line", image: "glow", status: .review),
        ZPost(day: 2, time: "12:00", channel: "Meta Ads", title: "Your 3pm, without the crash.", image: "energy", status: .review),
        ZPost(day: 3, time: "17:00", channel: "Instagram", title: "Weekend, bottled.", image: "fun", status: .scheduled),
        ZPost(day: 4, time: "10:00", channel: "Instagram", title: "Summer, bottled honestly.", image: "glow", status: .draft),
        ZPost(day: 5, time: "11:00", channel: "TikTok", title: "Recover: after the long day", image: "recover", status: .draft),
        ZPost(day: 8, time: "9:00", channel: "LinkedIn", title: "What 3pm looks like at Palmix", image: "energy", status: .draft),
        ZPost(day: 10, time: "18:00", channel: "Instagram", title: "Glow launch day", image: "glow", status: .scheduled),
    ]

    static let seedPlaybooks: [ZPlaybook] = [
        ZPlaybook(id: "launch", name: "Launch a product", line: "Two weeks from brief to launch day, across every channel.", from: "FANDS", length: "14 days", steps: [
            ZPlayStep(title: "Read the product and the market", tool: .research, done: true),
            ZPlayStep(title: "Write the angle and the brief", tool: .write, done: true),
            ZPlayStep(title: "Approve the brief", tool: .write, checkpoint: true, done: true),
            ZPlayStep(title: "Make the TikTok and three ads", tool: .video),
            ZPlayStep(title: "Size everything for every channel", tool: .layout),
            ZPlayStep(title: "Approve the creative", tool: .image, checkpoint: true),
            ZPlayStep(title: "Schedule launch week", tool: .publish),
        ], running: true, image: "glow"),
        ZPlaybook(id: "weekly", name: "Weekly social", line: "Five posts a week, planned on Monday, in your voice.", from: "FANDS", length: "Every week", steps: [
            ZPlayStep(title: "Look at what worked last week", tool: .research),
            ZPlayStep(title: "Plan five posts", tool: .write),
            ZPlayStep(title: "Approve the plan", tool: .write, checkpoint: true),
            ZPlayStep(title: "Make the pictures", tool: .image),
            ZPlayStep(title: "Schedule them", tool: .publish),
        ], image: "chill"),
        ZPlaybook(id: "ugc", name: "UGC set", line: "Six short clips of real-looking people talking about the product.", from: "FANDS", length: "3 days", steps: [
            ZPlayStep(title: "Write six scripts", tool: .write),
            ZPlayStep(title: "Approve the scripts", tool: .write, checkpoint: true),
            ZPlayStep(title: "Shoot the clips", tool: .video),
            ZPlayStep(title: "Cut them tight", tool: .video),
        ], image: "fun"),
        ZPlaybook(id: "beat", name: "Beat a competitor", line: "Read their ads, find what they leave open, take it.", from: "FANDS", length: "5 days", steps: [
            ZPlayStep(title: "Read their site and live ads", tool: .research),
            ZPlayStep(title: "Find the gap", tool: .research),
            ZPlayStep(title: "Approve the angle", tool: .write, checkpoint: true),
            ZPlayStep(title: "Make three ads that take it", tool: .image),
            ZPlayStep(title: "Run them against theirs", tool: .publish),
        ], image: "energy"),
        ZPlaybook(id: "holiday", name: "Holiday promo", line: "An offer, a countdown and a last-chance email.", from: "You", length: "10 days", steps: [
            ZPlayStep(title: "Pick the offer", tool: .write, checkpoint: true),
            ZPlayStep(title: "Make the countdown posts", tool: .image),
            ZPlayStep(title: "Write the emails", tool: .write),
        ], image: "recover"),
    ]

    static let seedResults: [ZResult] = [
        ZResult(title: "Slow is a flavour.", image: "chill", channel: "Instagram", spend: 420, clicks: 1310, ctr: 3.1, cpa: 4.20, week: [120, 150, 170, 160, 210, 240, 260]),
        ZResult(title: "Your 3pm, without the crash.", image: "energy", channel: "Meta Ads", spend: 610, clicks: 1520, ctr: 2.4, cpa: 5.10, week: [180, 200, 190, 230, 220, 250, 250]),
        ZResult(title: "Summer, bottled honestly.", image: "glow", channel: "Meta Ads", spend: 580, clicks: 980, ctr: 1.7, cpa: 7.80, week: [160, 150, 140, 140, 130, 130, 130]),
        ZResult(title: "We tested Focus on the people who make it.", image: "focus", channel: "LinkedIn", spend: 150, clicks: 410, ctr: 2.9, cpa: 3.60, week: [40, 55, 60, 58, 62, 66, 69]),
        ZResult(title: "Recover, sized for every channel", image: "recover", channel: "Meta Ads", spend: 390, clicks: 640, ctr: 1.5, cpa: 8.40, week: [100, 95, 92, 90, 88, 86, 89]),
    ]

    static let seedCompetitors: [ZCompetitor] = [
        ZCompetitor(id: "vitacoco", name: "Vita Coco", site: "vitacoco.com", owns: "Sport and recovery", ads: 14,
                    notes: ["Every ad has an athlete in it.", "No one talks about the afternoon.", "Big claims, small print."], image: "recover"),
        ZCompetitor(id: "harmless", name: "Harmless Harvest", site: "harmlessharvest.com", owns: "Pink water, organic", ads: 6,
                    notes: ["Soft, pastel, lots of white space.", "Talks about farmers, rarely about taste."], image: "fun"),
        ZCompetitor(id: "zola", name: "Zola", site: "drinkzola.com", owns: "Fruit blends for kids", ads: 3,
                    notes: ["Parents and lunchboxes.", "Quiet on social since spring."], image: "glow"),
    ]

    static let seedInbox: [ZInboxItem] = [
        ZInboxItem(kind: .approval, title: "Two ads need your OK", line: "Energy and Chill, for Instagram. Due Friday.", time: "9:14", image: "energy", route: .image),
        ZInboxItem(kind: .approval, title: "Approve the Glow creative", line: "Step 6 of the launch playbook is waiting on you.", time: "9:20", image: "glow", route: .playbooks),
        ZInboxItem(kind: .running, title: "Glow launch is on step 4 of 7", line: "Making the TikTok and three ads.", time: "Now", image: "glow", route: .playbooks),
        ZInboxItem(kind: .noticed, title: "Vita Coco started 4 new ads", line: "All sport. Still nobody on the afternoon.", time: "8:02", image: "recover", route: .research),
        ZInboxItem(kind: .done, title: "Tuesday's LinkedIn post is scheduled", line: "9:00, your best slot.", time: "Yesterday", image: "focus", route: .calendar),
        ZInboxItem(kind: .noticed, title: "Hands-and-sand is winning", line: "Chill's ad is up 38% on clicks this week.", time: "Yesterday", image: "chill", route: .results),
        ZInboxItem(kind: .done, title: "Twelve captions for Fun weekends", line: "Saved to the library.", time: "Mon", image: "fun", route: .library),
    ]

    static let seedMemories: [ZMemory] = [
        ZMemory(text: "Palmix never shows gyms or sweat.", source: "You, in the brand room"),
        ZMemory(text: "Hands-and-sand photos beat packshots by 38% on Instagram.", source: "Results, last 30 days"),
        ZMemory(text: "Tuesday 9:00 is the best slot for LinkedIn.", source: "Results, last 90 days"),
        ZMemory(text: "Vita Coco owns 'sport'. Nobody owns 'calm'.", source: "Research, Monday"),
        ZMemory(text: "Say 'coconut water', never 'hydration drink'.", source: "You, in a thread"),
    ]

    static let seedThreads: [ZThread] = [
        ZThread("Glow launch", updated: "Today", [
            ZMessage(fromFigaro: false, text: "We launch Glow on the 3rd. What do we need?", time: "9:02"),
            ZMessage(fromFigaro: true, text: "A TikTok, three ads and a LinkedIn post, all in the calm line that's working. Here's the TikTok first; it's the one that takes longest.",
                     answer: Answer.make(.storyboard, ask: "A TikTok for the Glow launch", place: .home),
                     tools: [.write, .image, .video], time: "9:03"),
            ZMessage(fromFigaro: false, text: "Love the pour. Make the ads too.", time: "9:10"),
            ZMessage(fromFigaro: true, text: "Three ways in. The first one uses the 3pm moment that's been winning for Energy.",
                     answer: Answer.make(.concepts, ask: "Three ads for Palmix Energy", place: .home),
                     tools: [.research, .write, .image, .layout], time: "9:12"),
        ]),
        ZThread("What is Vita Coco doing?", updated: "Mon", [
            ZMessage(fromFigaro: false, text: "What is Vita Coco doing lately?", time: "Mon 16:40"),
            ZMessage(fromFigaro: true, text: "They've gone all in on sport. That leaves the calm moments open for us.",
                     answer: Answer.make(.read, ask: "What is Vita Coco doing?", place: .home),
                     tools: [.research, .write], time: "Mon 16:41"),
        ]),
        ZThread("Tuesday LinkedIn post", updated: "Sun", [
            ZMessage(fromFigaro: false, text: "Something for LinkedIn about Focus.", time: "Sun 11:00"),
            ZMessage(fromFigaro: true, text: "Written in your voice and set for Tuesday at 9:00, your best slot.",
                     answer: Answer.make(.post, ask: "Next week's LinkedIn post", place: .home),
                     tools: [.research, .write, .image, .publish], time: "Sun 11:01"),
        ]),
    ]
}
