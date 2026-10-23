import SwiftUI

struct ReviewView: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) var dismiss
    @State private var tab = 0          // 0 all, 1 learned, 2 needs work
    @State private var open: String?
    @State private var practice: PracticeLaunch?

    /// Stable identity for the practice cover. Rebuilding this inside a Binding getter
    /// minted a new UUID every refresh and dismissed the session immediately.
    struct PracticeLaunch: Identifiable { let id = UUID(); let cards: [Card] }

    struct Group: Identifiable { let id: String; let title: String; let sub: String; let items: [Card] }

    var groups: [Group] {
        store.levelUnits.map { u in Group(id: u.id, title: L.s("Unit \(u.n)", "Урок \(u.n)") + " · " + u.ko, sub: u.title.text(store.state.lang), items: store.lib.cards(in: u.lv, u.n)) }
        + [Group(id: "natz", title: L.s("Naturalization · 종합평가 & 면접", "Натурализация · 종합평가 и 면접"), sub: "", items: store.lib.society + store.lib.interview),
           Group(id: "visa", title: L.s("Immigration office · 출입국", "Иммиграционная служба · 출입국"), sub: "", items: store.lib.visa),
           Group(id: "mine", title: L.s("My cards", "Мои карточки"), sub: "", items: store.mineCards)].filter { !$0.items.isEmpty }
    }

    func weak(_ s: SRS) -> Bool { s.n > 0 && (s.box < 2 || (s.last ?? 100) < 70) }
    func shown(_ c: Card) -> Bool {
        let s = store.srs(c.id)
        return tab == 0 || (tab == 1 ? s.n > 0 : weak(s))
    }

    var body: some View {
        ZStack {
            AuroraBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Button { dismiss() } label: { Image(systemName: "xmark").font(.title3.weight(.semibold)).foregroundStyle(Color.muted) }
                            .accessibilityLabel(L.s("Close", "Закрыть"))
                        Text(L.s("Review", "Повторение")).font(.largeTitle.weight(.heavy))
                    }
                    .padding(.top, 8)
                    Text(Levels.line(store.state.level, store.state.lang)).font(.subheadline).foregroundStyle(Color.muted)
                    stats
                    Picker("", selection: $tab) {
                        Text(L.s("All", "Все")).tag(0); Text(L.s("Learned", "Изученные")).tag(1); Text(L.s("Needs work", "Слабые")).tag(2)
                    }
                    .pickerStyle(.segmented)
                    ForEach(groups) { g in groupView(g) }
                    Text(L.s("Practice sessions save your scores but don't unlock apps.", "Тренировка сохраняет оценки, но не разблокирует приложения."))
                        .font(.footnote).foregroundStyle(Color.muted).frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 16).padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
        }
        .onAppear { if open == nil { open = "u\(store.state.unit)" } }
        .fullScreenCover(item: $practice) { p in
            QuizView(model: QuizModel(mode: .practice, cards: p.cards))
        }
    }

    var stats: some View {
        let items = store.allItems, st = items.map { store.srs($0.id) }
        let n = st.reduce(0) { $0 + $1.n }, ok = st.reduce(0) { $0 + $1.ok }
        let pron = items.filter { $0.kind == .pron || $0.kind == .line }.compactMap { store.srs($0.id).last }
        return VStack(spacing: 10) {
            HStack(spacing: 18) {
                Ring(value: store.coursePct, label: "\(Int(store.coursePct * 100))%")
                VStack(alignment: .leading, spacing: 4) {
                    Eyebrow(text: L.s("Level 3 course · goal 90%", "Курс уровня 3 · цель 90%"))
                    Text(L.s("\(store.masteredCount) of \(store.lib.book.count) mastered", "Освоено \(store.masteredCount) из \(store.lib.book.count)")).font(.headline)
                }
                Spacer()
            }
            .padding(16).glass()
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                tile("\(st.filter { $0.n > 0 }.count)/\(items.count)", L.s("Learned", "Изучено"), .ink)
                tile("\(st.filter { $0.box >= Store.masteredBox }.count)", L.s("Mastered", "Освоено"), .ink)
                tile(n > 0 ? "\(ok * 100 / n)%" : "—", L.s("Accuracy", "Точность"), .good)
                tile(pron.isEmpty ? "—" : "\(pron.reduce(0, +) / pron.count)%", L.s("Avg. pronunciation", "Ср. произношение"), .pron)
            }
            tile("\(store.state.tutorOk)/\(store.state.tutorQ)", L.s("Tutor answers correct", "Верных ответов репетитору"), .info)
        }
    }

    func tile(_ v: String, _ k: String, _ c: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(v).font(.system(size: 24, weight: .bold, design: .monospaced)).foregroundStyle(c)
            Text(k).font(.caption).foregroundStyle(Color.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(14).glass(18)
    }

    @ViewBuilder func groupView(_ g: Group) -> some View {
        let st = g.items.map { store.srs($0.id) }
        let m = st.filter { $0.box >= Store.masteredBox }.count, learned = st.filter { $0.n > 0 }.count
        let n = st.reduce(0) { $0 + $1.n }, ok = st.reduce(0) { $0 + $1.ok }
        let vis = g.items.filter(shown)
        if tab == 0 || !vis.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                Button { withAnimation { open = open == g.id ? nil : g.id } } label: {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(g.title).font(.headline).foregroundStyle(Color.ink)
                            if !g.sub.isEmpty { Text(g.sub).font(.footnote).foregroundStyle(Color.muted).lineLimit(2) }
                            Spacer()
                            Text("\(m)/\(g.items.count)" + (n > 0 ? " · \(ok * 100 / n)%" : "")).font(.caption.monospaced()).foregroundStyle(Color.muted)
                            Image(systemName: open == g.id ? "chevron.up" : "chevron.down").font(.caption).foregroundStyle(Color.muted)
                        }
                        GeometryReader { geo in
                            HStack(spacing: 0) {
                                Rectangle().fill(Color.good).frame(width: geo.size.width * CGFloat(m) / CGFloat(g.items.count))
                                Rectangle().fill(Color.info.opacity(0.6)).frame(width: geo.size.width * CGFloat(learned - m) / CGFloat(g.items.count))
                                Spacer(minLength: 0)
                            }
                            .background(Color.hair).clipShape(Capsule())
                        }
                        .frame(height: 5)
                    }
                    .padding(16)
                }
                .buttonStyle(.plain)
                if open == g.id {
                    VStack(alignment: .leading, spacing: 0) {
                        if vis.isEmpty {
                            Text(L.s("Nothing here yet. Practice a few cards and they'll show up with scores.", "Пока пусто. Пройдите несколько карточек — они появятся с оценками."))
                                .font(.footnote).foregroundStyle(Color.muted).padding(.bottom, 12)
                        }
                        ForEach(vis) { c in item(c) }
                        if !vis.isEmpty {
                            Button(L.s("Practice \(min(vis.count, 10))", "Тренировать \(min(vis.count, 10))")) {
                                practice = PracticeLaunch(cards: Array(vis.sorted { store.srs($0.id).box < store.srs($1.id).box }.prefix(10)))
                            }
                            .buttonStyle(PrimaryButton()).padding(.vertical, 12)
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
            .glass()
        }
    }

    func item(_ c: Card) -> some View {
        let s = store.srs(c.id)
        return VStack(alignment: .leading, spacing: 6) {
            Divider().overlay(Color.hair)
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    if let q = c.question { Text(q).font(.subheadline.weight(.semibold)); Text("→ " + c.plain).font(.footnote).foregroundStyle(Color.muted) }
                    else { RichKorean(text: c.text, size: 16) }
                }
                Spacer()
                scorePill(s)
            }
            Text((c.qMeaning ?? c.meaning).text(store.state.lang)).font(.footnote).foregroundStyle(Color.muted)
            HStack(spacing: 8) {
                Chip(text: c.kind.label + (c.gname.map { " · \($0)" } ?? ""), color: c.kind == .gram ? .gram : c.kind == .pron ? .pron : .info)
                HStack(spacing: 3) { ForEach(1...5, id: \.self) { b in Circle().fill(s.box >= b ? Color.good : Color.hair).frame(width: 7, height: 7) } }
                if s.n > 0 { Text("\(s.ok)/\(s.n)" + (s.best.map { " · best \($0)%" } ?? "")).font(.caption2.monospaced()).foregroundStyle(Color.muted) }
                Spacer()
                IconButton(system: "speaker.wave.2.fill", size: 34) { Speaker.shared.say(c.question ?? c.plain) }
                Button(L.s("Practice", "Тренировать")) { practice = PracticeLaunch(cards: [c]) }.font(.caption.weight(.semibold))
            }
        }
        .padding(.vertical, 6)
    }

    @ViewBuilder func scorePill(_ s: SRS) -> some View {
        if s.n == 0 { Chip(text: L.s("New", "Новое"), color: .muted) }
        else if let v = s.last { Chip(text: "\(v)%", color: scoreColor(v)) }
        else { Chip(text: s.lastOk == true ? "✓" : "✗", color: s.lastOk == true ? .good : .bad) }
    }
}
