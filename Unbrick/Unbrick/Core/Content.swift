import Foundation

// MARK: - Bundled content (exported from the KIIP 중급 1 textbook + workbook)

struct ContentFile: Decodable {
    let units: [UnitData]
    let society: [QAData]
    let interview: [QAData]
    let visa: [PhraseData]
}

struct UnitData: Decodable, Identifiable {
    let n: Int
    let ko: String
    let en: String
    let ru: String
    let grammar: [GrammarPoint]
    let pron: PronData
    let me: String
    let dialogue: [Line]
    let vocab: [Vocab]
    let sentences: [GramSentence]
    let questions: [Question]
    var listening: [Line]? = nil       // the unit's 듣기 conversation (from the textbook's listening scripts)
    var listeningTitle: String? = nil
    var id: Int { n }
    var title: Meaning { Meaning(en: en, ru: ru) }
}

struct GrammarPoint: Decodable {
    let name: String
    let en: String
    let ru: String
    var ko: String? = nil              // the textbook's own explanation
    var howEn: String? = nil           // how to form it
    var howRu: String? = nil
    var forms: [GrammarForm]? = nil    // the textbook's conjugation table
    var tips: [Tri]? = nil             // the textbook's Tip notes
}
struct GrammarForm: Decodable { let base: String; let form: String }
struct PronData: Decodable { let rule: String; let en: String; let ru: String; let sentences: [Tri] }
struct Tri: Decodable { let ko: String; let en: String; let ru: String }
struct Line: Decodable { let speaker: String; let ko: String; let en: String; let ru: String }
struct Vocab: Decodable { let ko: String; let en: String; let ru: String; let ex: String?; let exen: String?; let exru: String? }
struct GramSentence: Decodable { let g: String; let ko: String; let en: String; let ru: String }
struct Question: Decodable { let q: String; let qen: String; let qru: String; let t: String; let en: String; let ru: String; let k: [String]? }
struct QAData: Decodable { let id: String; let q: String; let qen: String; let qru: String; let t: String; let en: String; let ru: String; let k: [String] }
struct PhraseData: Decodable { let id: String; let ko: String; let en: String; let ru: String }

struct Meaning: Hashable {
    var en: String
    var ru: String
    func text(_ lang: Lang) -> String { lang == .ru && !ru.isEmpty ? ru : en }
}

// MARK: - Cards

enum Kind: String, Codable {
    case pron, line, word, gram, form, fact, open, recall, listen
    var label: String {
        switch self {
        case .form: return L.s("Grammar form", "Форма грамматики")
        case .word: return L.s("Vocabulary", "Лексика")
        case .gram: return L.s("Grammar", "Грамматика")
        case .fact: return L.s("Reading & culture", "Чтение и культура")
        case .pron: return L.s("Pronunciation", "Произношение")
        case .line: return L.s("Dialogue", "Диалог")
        case .recall: return L.s("Phrase", "Фраза")
        case .open: return L.s("Interview", "Собеседование")
        case .listen: return L.s("Listening", "Аудирование")
        }
    }
}

struct Card: Identifiable, Hashable {
    let id: String
    var kind: Kind
    var unit: Int?
    var text: String                 // Korean answer, with [[grammar]] and {{word|pron}} markup
    var meaning: Meaning
    var question: String? = nil      // Korean question for fact/open cards
    var qMeaning: Meaning? = nil
    var keys: [String] = []
    var prev: (speaker: String, ko: String, meaning: Meaning)? = nil
    var example: Tri? = nil
    var gname: String? = nil
    var speaker: String? = nil       // who says this line in a dialogue
    var scene = 0                    // 0 = 말하기 dialogue, 1 = 듣기 conversation
    var isMine = false

    var plain: String { Markup.plain(text) }
    var hidesAnswer: Bool { [.recall, .word, .gram, .form].contains(kind) }
    var isMeaningCard: Bool { [.recall, .fact, .open].contains(kind) }

    static func == (a: Card, b: Card) -> Bool { a.id == b.id && a.kind == b.kind }
    func hash(into h: inout Hasher) { h.combine(id); h.combine(kind) }
}

// MARK: - Library

final class Library {
    static let shared = Library()

    let units: [UnitData]
    let book: [Card]
    let society: [Card]
    let interview: [Card]
    let visa: [Card]
    /// Set when the bundled lessons could not be read, so the UI can say so instead of looking empty.
    let loadError: String?
    private var byUnit: [Int: [Card]] = [:]

    private init() {
        let decoded: ContentFile?
        let failure: String?
        let url = Bundle.main.url(forResource: "Content", withExtension: "json")
            ?? Bundle.main.url(forResource: "Content", withExtension: "json", subdirectory: "Resources")
        if let url {
            do {
                let data = try Data(contentsOf: url)
                decoded = try JSONDecoder().decode(ContentFile.self, from: data)
                failure = nil
            } catch {
                decoded = nil
                failure = error.localizedDescription
            }
        } else {
            decoded = nil
            failure = "Content.json is missing from the app bundle."
        }
        guard let file = decoded else {
            units = []; book = []; society = []; interview = []; visa = []
            loadError = failure ?? "Could not read lessons."
            return
        }
        loadError = file.units.isEmpty ? "Content.json has no units." : nil
        units = file.units
        var cards: [Card] = []
        for u in file.units {
            for (i, s) in u.pron.sentences.enumerated() {
                cards.append(Card(id: "p\(u.n)-\(i)", kind: .pron, unit: u.n, text: s.ko, meaning: Meaning(en: s.en, ru: s.ru)))
            }
            // Every line of both conversations is a speaking card, whoever says it.
            for (scene, lines, prefix) in [(0, u.dialogue, "d"), (1, u.listening ?? [], "l")] {
                for (i, d) in lines.enumerated() where !d.ko.isEmpty {
                    var c = Card(id: "\(prefix)\(u.n)-\(i)", kind: .line, unit: u.n, text: d.ko, meaning: Meaning(en: d.en, ru: d.ru))
                    if i > 0 { let p = lines[i - 1]; c.prev = (p.speaker, p.ko, Meaning(en: p.en, ru: p.ru)) }
                    c.speaker = d.speaker
                    c.scene = scene
                    cards.append(c)
                }
            }
            for (i, v) in u.vocab.enumerated() where !v.ko.isEmpty {
                var c = Card(id: "w\(u.n)-\(i)", kind: .word, unit: u.n, text: v.ko, meaning: Meaning(en: v.en, ru: v.ru))
                if let ex = v.ex, !ex.isEmpty { c.example = Tri(ko: ex, en: v.exen ?? "", ru: v.exru ?? "") }
                cards.append(c)
            }
            for (i, g) in u.sentences.enumerated() where g.ko.contains("[[") {
                var c = Card(id: "g\(u.n)-\(i)", kind: .gram, unit: u.n, text: g.ko, meaning: Meaning(en: g.en, ru: g.ru))
                c.gname = g.g
                cards.append(c)
            }
            for g in u.grammar {
                for (i, f) in (g.forms ?? []).enumerated() where !f.base.isEmpty && !f.form.isEmpty {
                    var c = Card(id: "f\(u.n)-\(Grader.normalized(g.name).prefix(12))-\(i)", kind: .form, unit: u.n, text: f.form,
                                 meaning: Meaning(en: "\(f.base) + \(g.name)", ru: "\(f.base) + \(g.name)"))
                    c.gname = g.name
                    c.example = Tri(ko: f.base, en: g.name, ru: g.name)
                    cards.append(c)
                }
            }
            for (i, q) in u.questions.enumerated() where !q.q.isEmpty {
                cards.append(Card(id: "c\(u.n)-\(i)", kind: .fact, unit: u.n, text: q.t, meaning: Meaning(en: q.en, ru: q.ru),
                                  question: q.q, qMeaning: Meaning(en: q.qen, ru: q.qru), keys: q.k ?? []))
            }
        }
        book = cards
        society = file.society.map { Card(id: $0.id, kind: .fact, text: $0.t, meaning: Meaning(en: $0.en, ru: $0.ru), question: $0.q, qMeaning: Meaning(en: $0.qen, ru: $0.qru), keys: $0.k) }
        interview = file.interview.map { Card(id: $0.id, kind: .open, text: $0.t, meaning: Meaning(en: $0.en, ru: $0.ru), question: $0.q, qMeaning: Meaning(en: $0.qen, ru: $0.qru)) }
        visa = file.visa.map { Card(id: $0.id, kind: .recall, text: $0.ko, meaning: Meaning(en: $0.en, ru: $0.ru)) }
        byUnit = Dictionary(grouping: book, by: { $0.unit ?? 0 })
    }

    func unit(_ n: Int) -> UnitData? { units.first { $0.n == n } }
    func cards(inUnit n: Int) -> [Card] { byUnit[n] ?? [] }

    /// The unit grammar point a sentence card practises, for its explanation.
    func grammarInfo(for c: Card) -> GrammarPoint? {
        guard let g = c.gname, let u = c.unit.flatMap(unit) else { return nil }
        return u.grammar.first { Library.sameGrammar($0.name, g) }
    }

    /// Grammar names are written slightly differently across sources ("이나 / 밖에" vs "이나/밖에", "피동 (passive)" vs "피동").
    static func sameGrammar(_ a: String, _ b: String) -> Bool {
        let x = Grader.normalized(String(a.split(separator: "(").first ?? "")), y = Grader.normalized(String(b.split(separator: "(").first ?? ""))
        if x.isEmpty || y.isEmpty { return false }
        // keep 사동① and 사동② apart
        let circled = { (s: String) in s.unicodeScalars.filter { (0x2460...0x2473).contains($0.value) }.map(String.init).joined() }
        if circled(a) != circled(b) && !circled(a).isEmpty && !circled(b).isEmpty { return false }
        return x == y || x.contains(y) || y.contains(x)
    }

    /// Every sentence and form card that practises one grammar point.
    func cards(for g: GrammarPoint, inUnit n: Int) -> [Card] {
        cards(inUnit: n).filter { ($0.kind == .gram || $0.kind == .form) && $0.gname.map { Library.sameGrammar(g.name, $0) } == true }
    }
}

// MARK: - Markup: [[grammar]] and {{word|pronunciation}}

enum Markup {
    private static let re = try! NSRegularExpression(pattern: #"\[\[(.+?)\]\]|\{\{(.+?)\|(.+?)\}\}"#)

    enum Token { case text(String), gram(String), pron(String, String) }

    static func tokens(_ s: String) -> [Token] {
        let ns = s as NSString
        var out: [Token] = []
        var last = 0
        for m in re.matches(in: s, range: NSRange(location: 0, length: ns.length)) {
            if m.range.location > last { out.append(.text(ns.substring(with: NSRange(location: last, length: m.range.location - last)))) }
            if m.range(at: 1).location != NSNotFound { out.append(.gram(ns.substring(with: m.range(at: 1)))) }
            else { out.append(.pron(ns.substring(with: m.range(at: 2)), ns.substring(with: m.range(at: 3)))) }
            last = m.range.location + m.range.length
        }
        if last < ns.length { out.append(.text(ns.substring(from: last))) }
        return out
    }

    static func plain(_ s: String) -> String {
        tokens(s).map { t -> String in
            switch t { case .text(let x), .gram(let x): return x; case .pron(let w, _): return w }
        }.joined()
    }

    static func pronWords(_ s: String) -> [(String, String)] {
        tokens(s).compactMap { if case .pron(let w, let p) = $0 { return (w, p) } else { return nil } }
    }

    static func grammarParts(_ s: String) -> [String] {
        tokens(s).compactMap { if case .gram(let g) = $0 { return g } else { return nil } }
    }
}

// MARK: - Grading

enum Grader {
    /// Lowercased, Hangul split into jamo (NFD), letters and digits only — so edit distance is letter-level.
    static func normalized(_ s: String) -> String {
        String(String.UnicodeScalarView(s.lowercased().decomposedStringWithCanonicalMapping.unicodeScalars.filter {
            $0.properties.isAlphabetic || $0.properties.numericType != nil
        }).filter { !(0x0300...0x036F).contains($0.value) })
    }

    static func levenshtein(_ a: [Unicode.Scalar], _ b: [Unicode.Scalar]) -> Int {
        if a.isEmpty { return b.count }
        if b.isEmpty { return a.count }
        var d = Array(0...b.count)
        for i in 1...a.count {
            var p = d[0]; d[0] = i
            for j in 1...b.count {
                let t = d[j]
                d[j] = min(d[j] + 1, d[j - 1] + 1, p + (a[i - 1] == b[j - 1] ? 0 : 1))
                p = t
            }
        }
        return d[b.count]
    }

    static func similarity(_ a: String, _ b: String) -> Double {
        let x = Array(normalized(a).unicodeScalars), y = Array(normalized(b).unicodeScalars)
        if x.isEmpty && y.isEmpty { return 1 }
        return 1 - Double(levenshtein(x, y)) / Double(max(x.count, y.count))
    }

    static func score(_ c: Card, said: String) -> Double {
        let n = normalized(said)
        if !c.keys.isEmpty && c.keys.contains(where: { let k = normalized($0); return !k.isEmpty && n.contains(k) }) { return 1 }
        if c.kind == .word && n.contains(normalized(c.plain)) { return 1 }
        return similarity(said, c.plain)
    }

    static func syllables(_ s: String) -> [Character] {
        s.precomposedStringWithCanonicalMapping.filter { $0.isLetter || $0.isNumber }
    }

    /// Indexes (into the target's letters) that were heard, via longest common subsequence.
    static func hits(target: String, said: String) -> Set<Int> {
        let a = syllables(target), b = syllables(said)
        let m = a.count, n = b.count
        if m == 0 || n == 0 { return [] }
        var t = Array(repeating: Array(repeating: 0, count: n + 1), count: m + 1)
        for i in stride(from: m - 1, through: 0, by: -1) {
            for j in stride(from: n - 1, through: 0, by: -1) {
                t[i][j] = a[i] == b[j] ? t[i + 1][j + 1] + 1 : max(t[i + 1][j], t[i][j + 1])
            }
        }
        var hit = Set<Int>(); var i = 0, j = 0
        while i < m && j < n {
            if a[i] == b[j] { hit.insert(i); i += 1; j += 1 }
            else if t[i + 1][j] >= t[i][j + 1] { i += 1 } else { j += 1 }
        }
        return hit
    }

    /// Each character of the plain target with whether it was heard (nil for spaces/punctuation).
    static func diff(target: String, said: String) -> [(Character, Bool?)] {
        let p = target.precomposedStringWithCanonicalMapping
        let hit = hits(target: p, said: said)
        var k = 0
        return p.map { ch in
            if ch.isLetter || ch.isNumber { defer { k += 1 }; return (ch, hit.contains(k)) }
            return (ch, nil)
        }
    }

    /// Pronunciation-rule words that had at least one syllable missed.
    static func missedPron(_ c: Card, said: String) -> [(String, String)] {
        let words = Markup.pronWords(c.text)
        if words.isEmpty { return [] }
        let flat = String(syllables(c.plain)), hit = hits(target: c.plain, said: said)
        var out: [(String, String)] = []
        for (w, p) in words {
            let ws = String(syllables(w))
            guard let r = flat.range(of: ws) else { continue }
            let at = flat.distance(from: flat.startIndex, to: r.lowerBound)
            if (at..<(at + ws.count)).contains(where: { !hit.contains($0) }) { out.append((w, p)) }
        }
        return out
    }
}
