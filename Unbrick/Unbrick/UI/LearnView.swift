import SwiftUI

struct LearnView: View {
    @EnvironmentObject var store: Store

    var body: some View {
        NavigationStack {
            ZStack {
                AuroraBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        Text(L.s("Learn", "Учёба")).font(.largeTitle.weight(.heavy)).padding(.top, 8)
                        Text(L.s("KIIP 3 · 중급 1 — every word, grammar point, dialogue and reading from your textbook and workbook.",
                                 "KIIP 3 · 중급 1 — вся лексика, грамматика, диалоги и тексты из учебника и рабочей тетради."))
                            .font(.subheadline).foregroundStyle(Color.muted)
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                            ForEach(store.lib.units) { u in
                                NavigationLink(value: u.n) { unitTile(u) }.buttonStyle(.plain)
                            }
                        }
                        Text(L.s("Other decks", "Другие наборы")).font(.title3.bold()).padding(.top, 6)
                        deckRow(L.s("Naturalization · 종합평가 & 면접", "Натурализация · 종합평가 и 면접"), "building.columns", store.lib.society + store.lib.interview)
                        deckRow(L.s("Immigration office · 출입국", "Иммиграционная служба · 출입국"), "person.text.rectangle", store.lib.visa)
                        MineSection()
                    }
                    .padding(.horizontal, 16).padding(.bottom, 30)
                }
                .scrollIndicators(.hidden)
            }
            .navigationDestination(for: Int.self) { UnitDetailView(n: $0) }
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    func unitTile(_ u: UnitData) -> some View {
        let p = store.unitPct(u.n), current = u.n == store.state.unit
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(L.s("Unit \(u.n)", "Урок \(u.n)")).font(.caption.monospaced()).foregroundStyle(Color.muted)
                Spacer()
                if current { Chip(text: L.s("Now", "Сейчас"), color: .accent) }
                else if p >= Store.goal { Image(systemName: "checkmark.seal.fill").foregroundStyle(Color.good) }
            }
            Text(u.ko).font(.headline).foregroundStyle(Color.ink)
            Text(u.title.text(store.state.lang)).font(.caption).foregroundStyle(Color.muted).lineLimit(1)
            ProgressView(value: p).tint(p >= Store.goal ? .good : .info)
            Text("\(Int(p * 100))% · \(store.lib.cards(inUnit: u.n).count) " + L.s("cards", "карт.")).font(.caption2.monospaced()).foregroundStyle(Color.muted)
        }
        .padding(14).frame(maxWidth: .infinity, alignment: .leading).glass(20)
        .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(current ? Color.accent : .clear, lineWidth: 1.5))
    }

    func deckRow(_ title: String, _ icon: String, _ cards: [Card]) -> some View {
        let m = cards.filter(store.mastered).count
        return HStack(spacing: 12) {
            Image(systemName: icon).font(.title3).foregroundStyle(Color.info).frame(width: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(L.s("\(m) of \(cards.count) mastered", "Освоено \(m) из \(cards.count)")).font(.caption).foregroundStyle(Color.muted)
            }
            Spacer()
            Button(L.s("Practice", "Тренировать")) {
                let pick = cards.sorted { store.srs($0.id).box < store.srs($1.id).box }.prefix(10).shuffled()
                store.launch = .practice(UUID(), Array(pick))
            }
            .font(.subheadline.weight(.semibold))
        }
        .padding(16).glass()
    }
}

struct UnitDetailView: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) var dismiss
    let n: Int
    @State private var filter: Kind? = nil

    var unit: UnitData? { store.lib.unit(n) }
    var cards: [Card] { store.lib.cards(inUnit: n) }
    var shown: [Card] { filter.map { f in cards.filter { $0.kind == f } } ?? cards }

    var body: some View {
        ZStack {
            AuroraBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 12) {
                        Button { dismiss() } label: { Image(systemName: "chevron.left").font(.title3.weight(.semibold)).foregroundStyle(Color.ink).frame(width: 40, height: 40).background(Color.white.opacity(0.09), in: Circle()) }
                        HomeButton()
                        Spacer()
                    }
                    .padding(.top, 8)
                    if let u = unit { header(u); content(u) }
                }
                .padding(.horizontal, 16).padding(.bottom, 30)
            }
            .scrollIndicators(.hidden)
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    func header(_ u: UnitData) -> some View {
        let p = store.unitPct(n)
        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Eyebrow(text: L.s("Unit \(n)", "Урок \(n)"))
                    Text(u.ko).font(.largeTitle.weight(.heavy))
                    Text(u.title.text(store.state.lang)).foregroundStyle(Color.muted)
                }
                Spacer()
                Ring(value: p, label: "\(Int(p * 100))%", size: 76)
            }
            let st = cards.map { store.srs($0.id) }
            let tried = st.reduce(0) { $0 + $1.n }, ok = st.reduce(0) { $0 + $1.ok }
            HStack(spacing: 10) {
                stat("\(cards.filter(store.mastered).count)/\(cards.count)", L.s("Mastered", "Освоено"))
                stat("\(st.filter { $0.n > 0 }.count)", L.s("Seen", "Пройдено"))
                stat(tried > 0 ? "\(ok * 100 / tried)%" : "—", L.s("Accuracy", "Точность"))
            }
            HStack(spacing: 8) {
                Button(L.s("Practice this unit", "Тренировать урок")) { store.practice(unit: n) }.buttonStyle(PrimaryButton())
                Button(L.s("Role-play", "Диалог")) { store.state.unit = n; store.launch = .quiz(.role(n)) }.buttonStyle(GlassButton())
            }
            if n != store.state.unit {
                Button(L.s("Make this my current unit", "Сделать текущим уроком")) { store.state.unit = n; store.flash(L.s("Unit \(n) is now your current unit.", "Урок \(n) — текущий.")) }
                    .font(.subheadline.weight(.semibold))
            }
        }
    }

    func stat(_ v: String, _ k: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(v).font(.system(size: 20, weight: .bold, design: .monospaced))
            Text(k).font(.caption).foregroundStyle(Color.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(12).glass(16)
    }

    @ViewBuilder func content(_ u: UnitData) -> some View {
        HStack {
            Text(L.s("Grammar lessons", "Уроки грамматики")).font(.title3.bold())
            Spacer()
            Text(L.s("80% each to finish the unit", "по 80% для завершения")).font(.caption).foregroundStyle(Color.muted)
        }
        ForEach(u.grammar, id: \.name) { g in GrammarLesson(grammar: g, unit: n) }
        vocabPanel
        Text(L.s("Pronunciation", "Произношение")).font(.title3.bold())
        TipBox(kind: .pron, title: u.pron.rule, bodyText: Meaning(en: u.pron.en, ru: u.pron.ru).text(store.state.lang))
        Text(L.s("Dialogue · 말하기", "Диалог · 말하기")).font(.title3.bold())
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(u.dialogue.enumerated()), id: \.offset) { _, d in
                HStack(alignment: .top, spacing: 10) {
                    Text(d.speaker).font(.caption.weight(.bold)).foregroundStyle(d.speaker == u.me ? Color.accent : Color.muted).frame(width: 64, alignment: .leading)
                    VStack(alignment: .leading, spacing: 3) {
                        RichKorean(text: d.ko, size: 16)
                        Text(Meaning(en: d.en, ru: d.ru).text(store.state.lang)).font(.caption).foregroundStyle(Color.muted)
                    }
                    Spacer(minLength: 0)
                    IconButton(system: "speaker.wave.2.fill", size: 32) { Speaker.shared.say(d.ko) }
                }
            }
        }
        .padding(14).glass()
        HStack {
            Text(L.s("All cards", "Все карточки")).font(.title3.bold())
            Spacer()
            Text("\(shown.count)").foregroundStyle(Color.muted)
        }
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterChip(nil, L.s("All", "Все"))
                ForEach([Kind.word, .gram, .form, .pron, .line, .fact], id: \.self) { k in filterChip(k, k.label) }
            }
        }
        if !shown.isEmpty {
            Button(L.s("Practice \(min(shown.count, 10)) of these", "Тренировать \(min(shown.count, 10))")) {
                let pick = shown.sorted { store.srs($0.id).box < store.srs($1.id).box }.prefix(10).shuffled()
                store.launch = .practice(UUID(), Array(pick))
            }
            .buttonStyle(GlassButton())
        }
        LazyVStack(alignment: .leading, spacing: 0) {
            ForEach(shown) { c in CardRow(card: c) }
        }
        .padding(.horizontal, 14).glass()
    }

    var vocabPanel: some View {
        let words = cards.filter { $0.kind == .word }
        let m = words.filter(store.mastered).count, seen = words.filter { store.srs($0.id).n > 0 }.count
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(L.s("Vocabulary", "Лексика")).font(.title3.bold())
                Spacer()
                Text("\(m)/\(words.count)").font(.headline.monospaced()).foregroundStyle(m == words.count && m > 0 ? Color.good : Color.ink)
            }
            ProgressView(value: words.isEmpty ? 0 : Double(m) / Double(words.count)).tint(.good)
            Text(L.s("\(words.count) words from this unit's vocabulary pages, word boxes and index · \(seen) seen · \(m) mastered",
                     "\(words.count) слов из словаря урока · пройдено \(seen) · освоено \(m)"))
                .font(.caption).foregroundStyle(Color.muted)
            Button(L.s("Drill new & weak words", "Тренировать новые и слабые слова")) {
                let pick = words.sorted { (store.srs($0.id).box, store.srs($0.id).n) < (store.srs($1.id).box, store.srs($1.id).n) }.prefix(10).shuffled()
                store.launch = .practice(UUID(), Array(pick))
            }
            .buttonStyle(GlassButton()).disabled(words.isEmpty)
        }
        .padding(16).glass()
    }

    func filterChip(_ k: Kind?, _ title: String) -> some View {
        Button { filter = k } label: {
            Text(title).font(.subheadline.weight(.semibold))
                .padding(.horizontal, 14).padding(.vertical, 8)
                .foregroundStyle(filter == k ? Color.white : Color.ink)
                .background(filter == k ? AnyShapeStyle(brandGradient) : AnyShapeStyle(Color.white.opacity(0.08)), in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

/// One card with its score, memory level, play and practice buttons.
struct CardRow: View {
    @EnvironmentObject var store: Store
    let card: Card

    var body: some View {
        let s = store.srs(card.id)
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    if let q = card.question { Text(q).font(.subheadline.weight(.semibold)); Text("→ " + card.plain).font(.footnote).foregroundStyle(Color.muted) }
                    else { RichKorean(text: card.text, size: 16) }
                }
                Spacer()
                pill(s)
            }
            Text((card.qMeaning ?? card.meaning).text(store.state.lang)).font(.footnote).foregroundStyle(Color.muted)
            if let ex = card.example { Text(ex.ko).font(.caption).foregroundStyle(Color.info) }
            HStack(spacing: 8) {
                Chip(text: card.kind.label + (card.gname.map { " · \($0)" } ?? ""), color: card.kind == .gram ? .gram : card.kind == .pron ? .pron : .info)
                HStack(spacing: 3) { ForEach(1...5, id: \.self) { b in Circle().fill(s.box >= b ? Color.good : Color.hair).frame(width: 6, height: 6) } }
                if s.n > 0 { Text("\(s.ok)/\(s.n)" + (s.best.map { " · \($0)%" } ?? "")).font(.caption2.monospaced()).foregroundStyle(Color.muted) }
                Spacer()
                IconButton(system: "speaker.wave.2.fill", size: 32) { Speaker.shared.say(card.question ?? card.plain) }
                Button(L.s("Practice", "Тренировать")) { store.launch = .practice(UUID(), [card]) }.font(.caption.weight(.semibold))
            }
            Divider().overlay(Color.hair).padding(.top, 6)
        }
        .padding(.top, 10)
    }

    @ViewBuilder func pill(_ s: SRS) -> some View {
        if s.n == 0 { Chip(text: L.s("New", "Новое"), color: .muted) }
        else if let v = s.last { Chip(text: "\(v)%", color: scoreColor(v)) }
        else { Chip(text: s.lastOk == true ? "✓" : "✗", color: s.lastOk == true ? .good : .bad) }
    }
}

/// A full lesson for one grammar point: what it means, how to form it, the book's table and tips, every example, and a drill.
struct GrammarLesson: View {
    @EnvironmentObject var store: Store
    let grammar: GrammarPoint
    let unit: Int
    @State private var open = false

    var body: some View {
        let cards = store.lib.cards(for: grammar, inUnit: unit)
        let p = store.grammarPct(grammar, unit: unit)
        let lang = store.state.lang
        VStack(alignment: .leading, spacing: 10) {
            Button { withAnimation { open.toggle() } } label: {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(grammar.name).font(.title3.weight(.heavy)).foregroundStyle(Color.gram)
                        Spacer()
                        Text("\(Int(p * 100))%").font(.subheadline.monospaced().bold()).foregroundStyle(p >= Store.grammarGoal ? Color.good : Color.ink)
                        Image(systemName: open ? "chevron.up" : "chevron.down").font(.caption).foregroundStyle(Color.muted)
                    }
                    Text(Meaning(en: grammar.en, ru: grammar.ru).text(lang)).font(.subheadline).foregroundStyle(Color.ink).multilineTextAlignment(.leading)
                    ProgressView(value: p).tint(p >= Store.grammarGoal ? .good : .gram)
                }
            }
            .buttonStyle(.plain)

            if open {
                if let ko = grammar.ko, !ko.isEmpty {
                    Text(ko).font(.footnote).foregroundStyle(Color.muted).padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading).background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
                }
                if let how = lang == .ru ? grammar.howRu : grammar.howEn, !how.isEmpty {
                    TipBox(kind: .gram, title: L.s("How to form it", "Как образовать"), bodyText: how)
                }
                if let forms = grammar.forms, !forms.isEmpty {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                        ForEach(Array(forms.enumerated()), id: \.offset) { _, f in
                            Button { Speaker.shared.say(f.form) } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(f.base).font(.caption).foregroundStyle(Color.muted)
                                    Text(f.form).font(.subheadline.bold()).foregroundStyle(Color.gram)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading).padding(10)
                                .background(Color.gram.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                ForEach(Array((grammar.tips ?? []).enumerated()), id: \.offset) { _, t in
                    TipBox(kind: .info, title: "Tip", bodyText: t.ko + "\n" + Meaning(en: t.en, ru: t.ru).text(lang))
                }
                let examples = cards.filter { $0.kind == .gram }
                if !examples.isEmpty {
                    Eyebrow(text: L.s("\(examples.count) examples", "Примеров: \(examples.count)"))
                    ForEach(examples) { c in
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 2) {
                                RichKorean(text: c.text, size: 16)
                                Text(c.meaning.text(lang)).font(.caption).foregroundStyle(Color.muted)
                            }
                            Spacer(minLength: 0)
                            IconButton(system: "speaker.wave.2.fill", size: 32) { Speaker.shared.say(c.plain) }
                        }
                    }
                }
            }
            Button(L.s("Drill this grammar (\(min(cards.count, 10)))", "Тренировать эту грамматику (\(min(cards.count, 10)))")) {
                let pick = cards.sorted { store.srs($0.id).box < store.srs($1.id).box }.prefix(10).shuffled()
                store.launch = .practice(UUID(), Array(pick))
            }
            .buttonStyle(GlassButton()).disabled(cards.isEmpty)
        }
        .padding(16).glass()
    }
}
