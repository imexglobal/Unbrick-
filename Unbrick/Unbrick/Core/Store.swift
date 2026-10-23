import Foundation
import SwiftUI
import UserNotifications

enum Lang: String, Codable, CaseIterable { case en, ru }

/// Inline English/Russian strings: L.s("English", "Русский").
enum L {
    static var lang: Lang { Store.shared.state.lang }
    static func s(_ en: String, _ ru: String) -> String { lang == .ru ? ru : en }
}

enum Track: String, Codable, CaseIterable {
    case kiip, natz, visa
    var title: String {
        switch self {
        case .kiip: return "KIIP (사회통합프로그램)"
        case .natz: return L.s("Naturalization (일반귀화)", "Натурализация (일반귀화)")
        case .visa: return L.s("Visa & life in Korea", "Виза и жизнь в Корее")
        }
    }
    var detail: String {
        switch self {
        case .kiip: return L.s("Pass the next KIIP level.", "Сдать следующий уровень KIIP.")
        case .natz: return L.s("종합평가 written test and the 귀화 interview.", "Экзамен 종합평가 и собеседование 귀화.")
        case .visa: return L.s("출입국 office, 외국인등록증, daily life.", "Иммиграционная служба, 외국인등록증, быт.")
        }
    }
}

enum Intensity: String, Codable, CaseIterable {
    case gentle, steady, strict, exam
    var cards: Int { [3, 5, 8, 10][index] }
    var pass: Int { [2, 4, 7, 10][index] }
    var minutes: Int { [30, 15, 10, 5][index] }
    var tutor: Int { [2, 3, 5, 6][index] }
    private var index: Int { Self.allCases.firstIndex(of: self)! }
    var title: String {
        switch self {
        case .gentle: return L.s("Gentle", "Мягко")
        case .steady: return L.s("Steady", "Стабильно")
        case .strict: return L.s("Strict", "Строго")
        case .exam: return L.s("Exam month", "Месяц экзамена")
        }
    }
    var detail: String {
        L.s("\(cards) cards, \(pass) right · \(minutes) min · tutor: \(tutor)",
            "\(cards) карточек, \(pass) верно · \(minutes) мин · репетитор: \(tutor)")
    }
}

struct SRS: Codable {
    var box = 0
    var seen: Double = 0
    var n = 0
    var ok = 0
    var last: Int?
    var best: Int?
    var lastOk: Bool?
}

struct DayLog: Codable {
    var answered = 0
    var correct = 0
    var unlocks = 0
    var units: [Int] = []
    /// "level-unit" pairs studied that day. Older saves only have `units`, which were level 3.
    var marks: [String] = []

    init() {}

    /// A missing `marks` key must not fail the decode, or the whole activity history is dropped.
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        answered = (try? c.decode(Int.self, forKey: .answered)) ?? 0
        correct = (try? c.decode(Int.self, forKey: .correct)) ?? 0
        unlocks = (try? c.decode(Int.self, forKey: .unlocks)) ?? 0
        units = (try? c.decode([Int].self, forKey: .units)) ?? []
        marks = (try? c.decode([String].self, forKey: .marks)) ?? []
    }

    func encode(to e: Encoder) throws {
        var c = e.container(keyedBy: CodingKeys.self)
        try c.encode(answered, forKey: .answered)
        try c.encode(correct, forKey: .correct)
        try c.encode(unlocks, forKey: .unlocks)
        try c.encode(units, forKey: .units)
        try c.encode(marks, forKey: .marks)
    }

    private enum CodingKeys: String, CodingKey { case answered, correct, unlocks, units, marks }
}

enum Tab: Hashable { case home, learn, calendar, profile }

struct MineCard: Codable, Identifiable { var id: String; var t: String; var m: String }
struct BlockedApp: Codable, Identifiable { var id: String { name }; var name: String; var color: String; var blocked: Bool }

struct AppState: Codable {
    var setupDone = false
    var lang: Lang = .en
    var track: Track = .kiip
    var level = 3
    var unit = 1
    var date: Date?
    var intensity: Intensity = .steady
    var until: Double = 0
    var streak = 0
    var lastDay = ""
    var xp = 0
    var srs: [String: SRS] = [:]
    var mine: [MineCard] = []
    var tutorQ = 0
    var tutorOk = 0
    var l3done = false
    var doneLevels: [Int] = []
    var screenTimeReady = false     // passcode + App Limits set up in iOS Settings
    var activity: [String: DayLog] = [:]   // "yyyy-MM-dd" → what was studied that day
    var apps: [BlockedApp] = [
        .init(name: "Instagram", color: "C13584", blocked: true), .init(name: "TikTok", color: "25C4D8", blocked: true),
        .init(name: "YouTube", color: "FF3B30", blocked: true), .init(name: "KakaoTalk", color: "C9A400", blocked: false),
        .init(name: "X", color: "3A3A3C", blocked: true), .init(name: "Reddit", color: "FF5700", blocked: true),
        .init(name: "Netflix", color: "B20710", blocked: false), .init(name: "Naver", color: "03C75A", blocked: false)]

    init() {}
    // Tolerant decoding: a field added in a later version never wipes saved progress.
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        let def = AppState()
        setupDone = (try? c.decode(Bool.self, forKey: .setupDone)) ?? def.setupDone
        lang = (try? c.decode(Lang.self, forKey: .lang)) ?? def.lang
        track = (try? c.decode(Track.self, forKey: .track)) ?? def.track
        level = (try? c.decode(Int.self, forKey: .level)) ?? def.level
        unit = (try? c.decode(Int.self, forKey: .unit)) ?? def.unit
        date = try? c.decode(Date.self, forKey: .date)
        intensity = (try? c.decode(Intensity.self, forKey: .intensity)) ?? def.intensity
        until = (try? c.decode(Double.self, forKey: .until)) ?? 0
        streak = (try? c.decode(Int.self, forKey: .streak)) ?? 0
        lastDay = (try? c.decode(String.self, forKey: .lastDay)) ?? ""
        xp = (try? c.decode(Int.self, forKey: .xp)) ?? 0
        srs = (try? c.decode([String: SRS].self, forKey: .srs)) ?? [:]
        mine = (try? c.decode([MineCard].self, forKey: .mine)) ?? []
        tutorQ = (try? c.decode(Int.self, forKey: .tutorQ)) ?? 0
        tutorOk = (try? c.decode(Int.self, forKey: .tutorOk)) ?? 0
        l3done = (try? c.decode(Bool.self, forKey: .l3done)) ?? false
        doneLevels = (try? c.decode([Int].self, forKey: .doneLevels)) ?? []
        screenTimeReady = (try? c.decode(Bool.self, forKey: .screenTimeReady)) ?? false
        activity = (try? c.decode([String: DayLog].self, forKey: .activity)) ?? [:]
        apps = (try? c.decode([BlockedApp].self, forKey: .apps)) ?? def.apps
    }
}

final class Store: ObservableObject {
    static let shared = Store()
    static let masteredBox = 3
    static let goal = 0.9
    private static let intervals: [Double] = [0, 0, 1, 2, 4, 8, 16]   // days, by box

    @Published var state: AppState { didSet { save() } }
    @Published var toast: String?
    @Published var shieldApp: String?
    @Published var tab: Tab = .home
    @Published var launch: Sheet?          // full-screen session or page opened from any tab

    /// Gregorian `yyyy-MM-dd` in the device time zone, with ASCII digits.
    /// A locale-sensitive DateFormatter can write a different key than the streak uses.
    static func dayKey(_ d: Date = Date()) -> String {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .current
        let p = cal.dateComponents([.year, .month, .day], from: d)
        return String(format: "%04d-%02d-%02d", p.year ?? 0, p.month ?? 0, p.day ?? 0)
    }

    /// Start a card session in a specific unit, so every card comes from that unit.
    func practice(unit n: Int) {
        state.unit = n
        launch = .quiz(.cards)
    }

    func goHome() {
        launch = nil
        shieldApp = nil
        tab = .home
    }
    let lib = Library.shared

    private static var fileURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("state.json")
    }

    private init() {
        if let data = try? Data(contentsOf: Self.fileURL), let s = try? JSONDecoder().decode(AppState.self, from: data) { state = s }
        else { state = AppState() }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(state) { try? data.write(to: Self.fileURL, options: .atomic) }
    }

    /// Read straight from disk, for App Intents that may run before the UI.
    static func lockedNow() -> Bool {
        guard let data = try? Data(contentsOf: fileURL), let s = try? JSONDecoder().decode(AppState.self, from: data) else { return true }
        return s.until <= Date().timeIntervalSince1970
    }

    // MARK: lock

    var unlocked: Bool { state.until > Date().timeIntervalSince1970 }
    var remaining: TimeInterval { max(0, state.until - Date().timeIntervalSince1970) }

    func grantUnlock() {
        state.until = Date().addingTimeInterval(TimeInterval(state.intensity.minutes * 60)).timeIntervalSince1970
        let today = Self.dayKey()
        let prior = Calendar(identifier: .gregorian).date(byAdding: .day, value: -1, to: Date()).map(Self.dayKey) ?? ""
        if state.lastDay != today { state.streak = state.lastDay == prior ? state.streak + 1 : 1; state.lastDay = today }
        state.activity[Self.dayKey(), default: DayLog()].unlocks += 1
        scheduleRelockNotice()
    }

    func relock() {
        state.until = 0
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["relock"])
    }

    private func scheduleRelockNotice() {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = "Unbrick"
            content.body = L.s("Time's up. Practice again to see your Screen Time passcode. 화이팅!", "Время вышло. Позанимайтесь снова, чтобы увидеть код Экранного времени. 화이팅!")
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, self.remaining), repeats: false)
            center.removePendingNotificationRequests(withIdentifiers: ["relock"])
            center.add(UNNotificationRequest(identifier: "relock", content: content, trigger: trigger))
        }
    }

    func handle(_ url: URL) {
        guard url.scheme == "unbrick" else { return }
        let app = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == "app" }?.value
        if url.host == "shield" { showShield(app ?? L.s("This app", "Это приложение")) }
    }

    func showShield(_ app: String) {
        if unlocked { flash(L.s("\(app) is open for \(Int(remaining / 60) + 1) more min.", "\(app) открыт ещё \(Int(remaining / 60) + 1) мин.")) }
        else { shieldApp = app }
    }

    func flash(_ text: String) {
        toast = text
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in if self?.toast == text { self?.toast = nil } }
    }

    // MARK: mastery

    func srs(_ id: String) -> SRS { state.srs[id] ?? SRS() }
    func mastered(_ c: Card) -> Bool { srs(c.id).box >= Self.masteredBox }
    var levelBook: [Card] { lib.cards(forLevel: state.level) }
    var levelUnits: [UnitData] { lib.units(for: state.level) }

    func setLevel(_ level: Int) {
        state.level = level
        let numbers = levelUnits.map(\.n)
        if !numbers.contains(state.unit) { state.unit = numbers.min() ?? 1 }
    }

    func nextUnit(after n: Int) -> Int? { levelUnits.map(\.n).sorted().first { $0 > n } }

    func unitPct(_ n: Int) -> Double {
        let a = lib.cards(in: state.level, n)
        return a.isEmpty ? 0 : Double(a.filter(mastered).count) / Double(a.count)
    }
    var coursePct: Double { levelBook.isEmpty ? 0 : Double(levelBook.filter(mastered).count) / Double(levelBook.count) }
    var masteredCount: Int { levelBook.filter(mastered).count }

    var mineCards: [Card] { state.mine.map { Card(id: "m" + $0.id, kind: .recall, text: $0.t, meaning: Meaning(en: $0.m, ru: $0.m), isMine: true) } }
    var allItems: [Card] { lib.book + lib.society + lib.interview + lib.visa + mineCards }

    func pool() -> [Card] {
        // Cards come only from the unit you chose; after 90% of Level 3, everything is in review.
        let book = coursePct >= Self.goal ? levelBook : lib.cards(in: state.level, state.unit)
        switch state.track {
        case .natz: return mineCards + lib.society + lib.interview + book.filter { $0.kind == .pron }
        case .visa: return mineCards + lib.visa + book
        case .kiip: return mineCards + book
        }
    }

    func isDue(_ c: Card) -> Bool {
        let s = srs(c.id)
        if s.n == 0 { return true }
        return Date().timeIntervalSince1970 - s.seen >= Self.intervals[min(s.box, 6)] * 86400
    }

    // MARK: grammar & vocabulary mastery

    func grammarPct(_ g: GrammarPoint, unit n: Int) -> Double {
        let a = lib.cards(for: g, in: state.level, n)
        return a.isEmpty ? 1 : Double(a.filter(mastered).count) / Double(a.count)
    }
    func vocabPct(unit n: Int) -> Double {
        let a = lib.cards(in: state.level, n).filter { $0.kind == .word }
        return a.isEmpty ? 1 : Double(a.filter(mastered).count) / Double(a.count)
    }
    static let grammarGoal = 0.8

    /// A unit is done when 90% of its cards are mastered AND every grammar point is at least 80% mastered.
    func unitComplete(_ n: Int) -> Bool {
        guard unitPct(n) >= Self.goal, let u = lib.unit(state.level, n) else { return false }
        return u.grammar.allSatisfy { grammarPct($0, unit: n) >= Self.grammarGoal }
    }

    /// The grammar point in a unit that needs the most work.
    func weakestGrammar(unit n: Int) -> GrammarPoint? {
        lib.unit(state.level, n)?.grammar.min { grammarPct($0, unit: n) < grammarPct($1, unit: n) }
    }

    // MARK: sessions

    private func priority(_ c: Card) -> Double {
        let s = srs(c.id)
        return (c.isMine ? -4 : 0) + (isDue(c) ? 0 : 20) + Double(s.box * 2) + (s.n == 0 ? -1 : 0) + Double.random(in: 0..<2.5)
    }

    /// Cards from the current unit, always mixing grammar (weakest point first) and vocabulary with the rest.
    func pickCards() -> [Card] {
        let p = pool(), count = state.intensity.cards
        let ranked = p.map { ($0, priority($0)) }.sorted { $0.1 < $1.1 }.map { $0.0 }
        var picked: [Card] = []
        func take(_ c: Card?) { if let c, !picked.contains(where: { $0.id == c.id }), picked.count < count { picked.append(c) } }
        if state.track == .kiip, coursePct < Self.goal, let g = weakestGrammar(unit: state.unit) {
            let gc = ranked.filter { ($0.kind == .gram || $0.kind == .form) && $0.gname.map { Library.sameGrammar(g.name, $0) } == true }
            take(gc.first)
            if count >= 5 { take(gc.dropFirst().first) }
        }
        take(ranked.first { $0.kind == .word })
        if count >= 5 { take(ranked.first { $0.kind == .word && !picked.contains($0) }) }
        ranked.forEach(take)
        picked.shuffle()

        let meanings = p.filter { $0.question == nil }
        var listened = false
        for i in picked.indices {
            let k = picked[i].kind
            if !listened && [.line, .recall, .word].contains(k) && meanings.count >= 4 && picked.count >= 4 {
                picked[i].kind = .listen; listened = true
            } else if k == .line && picked[i].plain.count <= 26 && Bool.random() {
                picked[i].kind = .recall
            }
        }
        return picked
    }

    /// Role-play: the 말하기 dialogue in your role, then the same dialogue in the other role, then the 듣기 conversation.
    func roleplayCards(unit n: Int) -> [Card] {
        guard let u = lib.unit(state.level, n) else { return [] }
        let lines = lib.cards(in: state.level, n).filter { $0.kind == .line }
        let talk = lines.filter { $0.scene == 0 }, listen = lines.filter { $0.scene == 1 }
        return talk.filter { $0.speaker == u.me } + talk.filter { $0.speaker != u.me } + listen
    }

    /// Due spaced-repetition cards from earlier chapters of this level, so they stay in memory.
    /// Order follows the book, so a skipped number (중급 2 has no unit 8) still counts as earlier.
    var dueReview: [Card] {
        let earlier = Set(levelUnits.map(\.n).prefix { $0 != state.unit })
        return levelBook.filter { earlier.contains($0.unit ?? -1) && srs($0.id).n > 0 && isDue($0) }
            + (lib.society + lib.interview + lib.visa + mineCards).filter { srs($0.id).n > 0 && isDue($0) }
    }

    /// What was studied on a calendar day. Old logs stored unit numbers only, and those were level 3.
    func studiedLabel(_ log: DayLog) -> String {
        if !log.marks.isEmpty {
            return log.marks.sorted().map { mark in
                let parts = mark.split(separator: "-").compactMap { Int($0) }
                guard parts.count == 2, let u = lib.unit(parts[0], parts[1]) else { return mark }
                return "L\(parts[0]) · \(parts[1]) \(u.ko)"
            }.joined(separator: " · ")
        }
        return log.units.sorted().map { n in
            let title = lib.unit(3, n)?.ko ?? ""
            return "3 · \(n) \(title)"
        }.joined(separator: " · ")
    }

    func reviewCards() -> [Card] {
        Array(dueReview.sorted { srs($0.id).box < srs($1.id).box }.prefix(state.intensity.cards)).shuffled()
    }


    /// Saves one answer; returns milestone messages (unit opened, course done).
    @discardableResult
    func record(_ c: Card, ok: Bool, pct: Int?, practice: Bool) -> [String] {
        var s = srs(c.id)
        s.box = ok ? min(s.box + 1, 5) : 0
        s.seen = Date().timeIntervalSince1970
        s.n += 1
        if ok { s.ok += 1; state.xp += 10 }
        s.lastOk = ok
        if let pct { s.last = pct; s.best = max(s.best ?? 0, pct) }
        state.srs[c.id] = s
        var day = state.activity[Self.dayKey(), default: DayLog()]
        day.answered += 1
        if ok { day.correct += 1 }
        if let u = c.unit {
            if !day.units.contains(u) { day.units.append(u) }
            let mark = "\(c.level)-\(u)"
            if !day.marks.contains(mark) { day.marks.append(mark) }
        }
        state.activity[Self.dayKey()] = day
        var notes: [String] = []
        if !practice && state.track == .kiip && unitComplete(state.unit), let next = nextUnit(after: state.unit) {
            let finished = state.unit
            state.unit = next
            notes.append(L.s("Unit \(finished) complete: 90% mastered with every grammar point learned. Unit \(next) is open.",
                             "Урок \(finished) пройден: 90% и вся грамматика освоена. Открыт урок \(next)."))
        }
        if coursePct >= Self.goal && !state.doneLevels.contains(state.level) {
            state.doneLevels.append(state.level)
            if state.level == 3 { state.l3done = true }
            let name = Levels.ko(state.level)
            notes.append(L.s("\(name) is 90% mastered. 축하해요!", "\(name) освоен на 90%. 축하해요!"))
        }
        return notes
    }

    var goalText: String {
        switch state.track {
        case .kiip: return "KIIP \(state.level) · \(Levels.ko(state.level))" + L.s(" · Unit \(state.unit)", " · Урок \(state.unit)")
        default: return state.track.title
        }
    }

    var daysLeft: Int? {
        guard let d = state.date else { return nil }
        return Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: Date()), to: Calendar.current.startOfDay(for: d)).day
    }
}
