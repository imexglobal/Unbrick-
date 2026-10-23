import SwiftUI

/// Anything opened full-screen from a tab: a practice session, the tutor, review, setup, blocking.
enum Sheet: Identifiable {
    case quiz(QuizMode), practice(UUID, [Card]), tutor, scene(Int), review, setup, blocking
    var id: String {
        switch self {
        case .quiz(let m): return "quiz-\(m)"
        case .practice(let u, _): return "practice-\(u)"
        case .tutor: return "tutor"; case .scene(let n): return "scene-\(n)"; case .review: return "review"; case .setup: return "setup"; case .blocking: return "blocking"
        }
    }
}

struct HomeView: View {
    @EnvironmentObject var store: Store
    @State private var editingApps = false

    var body: some View {
        ZStack {
            AuroraBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    lockCard
                    currentUnitCard
                    if !store.dueReview.isEmpty { reviewCard }
                    weekStrip
                    goalCard
                    appsSection
                }
                .padding(.horizontal, 16).padding(.bottom, 30)
            }
            .scrollIndicators(.hidden)
        }
    }

    var header: some View {
        HStack {
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 7).fill(LinearGradient(colors: [.accent2, .info], startPoint: .topLeading, endPoint: .bottomTrailing)).frame(width: 22, height: 22)
                Text("Unbrick").font(.title2.weight(.heavy))
            }
            Spacer()
            pill("🔥 \(store.state.streak)", L.s("days", "дн."))
            pill("\(store.state.xp)", "xp")
        }
        .padding(.top, 8)
    }

    func pill(_ v: String, _ k: String) -> some View {
        (Text(v).bold() + Text(" " + k).foregroundStyle(Color.muted)).font(.caption.monospaced())
            .padding(.horizontal, 10).padding(.vertical, 6).glass(999)
    }

    // MARK: lock

    var lockCard: some View {
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            VStack(alignment: .leading, spacing: 18) {
                let blocked = store.state.apps.filter(\.blocked).count
                if store.unlocked {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Eyebrow(text: L.s("Unlocked for", "Открыто ещё"))
                            Text(timeString(store.remaining)).font(.system(size: 46, weight: .bold, design: .monospaced)).foregroundStyle(Color.good)
                        }
                        Spacer()
                        orb(open: true)
                    }
                    if store.state.screenTimeReady, let code = ScreenTimeCode.value {
                        VStack(alignment: .leading, spacing: 6) {
                            Eyebrow(text: L.s("Screen Time passcode", "Код-пароль Экранного времени"))
                            Text(code).font(.system(size: 40, weight: .heavy, design: .monospaced)).kerning(10)
                            Text(L.s("In the blocked app: Ask for More Time › Enter Screen Time Passcode › Approve for 15 Minutes.",
                                     "В заблокированном приложении: «Попросить больше времени» › «Ввести код-пароль» › «Одобрить на 15 минут»."))
                                .font(.footnote).foregroundStyle(Color.muted)
                        }
                        .padding(14).frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.good.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))
                    } else {
                        Text(store.state.screenTimeReady
                             ? L.s("Screen Time passcode is hidden until you earn an unlock. These tiles are practice shortcuts.", "Код Экранного времени скрыт, пока вы не заработаете разблокировку. Эти значки — только тренировка.")
                             : L.s("\(blocked) practice shortcuts. They brick again at zero. They do not close other apps.", "Тренировочных ярлыков: \(blocked). При нуле снова щит. Другие приложения сами не закрываются."))
                            .foregroundStyle(Color.muted)
                    }
                    Button(L.s("Lock now", "Заблокировать")) { store.relock() }.buttonStyle(GlassButton())
                } else {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(L.s("Time to practice", "Время заниматься")).font(.system(size: 34, weight: .heavy))
                            Text(store.state.screenTimeReady
                                 ? L.s("Screen Time is on · \(store.state.intensity.minutes) min per unlock", "Экранное время включено · \(store.state.intensity.minutes) мин за раз")
                                 : L.s("Practice shield · Screen Time is not set up yet", "Тренировочный щит · Экранное время ещё не настроено"))
                                .font(.subheadline).foregroundStyle(Color.muted)
                        }
                        Spacer()
                        orb(open: false)
                    }
                    HStack(spacing: 8) {
                        Button(L.s("Cards", "Карточки")) { store.launch = .quiz(.cards) }.buttonStyle(PrimaryButton())
                        Button(L.s("Role-play", "Диалог")) { store.launch = .quiz(.role(store.state.unit)) }.buttonStyle(GlassButton())
                        Button(L.s("AI tutor", "Репетитор")) { store.launch = .tutor }.buttonStyle(GlassButton())
                    }
                }
            }
            .padding(22).glass()
        }
    }

    func orb(open: Bool) -> some View {
        Image(systemName: open ? "lock.open.fill" : "lock.fill").font(.title2).foregroundStyle(.white)
            .frame(width: 56, height: 56)
            .background(Circle().fill(open ? AnyShapeStyle(LinearGradient(colors: [Color(hex: "9BE15D"), .good], startPoint: .top, endPoint: .bottom)) : AnyShapeStyle(brandGradient)))
            .shadow(color: (open ? Color.good : .accent).opacity(0.55), radius: 20)
    }

    func timeString(_ t: TimeInterval) -> String { String(format: "%02d:%02d", Int(t) / 60, Int(t) % 60) }

    // MARK: current unit

    var currentUnitCard: some View {
        let n = store.state.unit, p = store.unitPct(n)
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Eyebrow(text: L.s("Studying now · Unit \(n)", "Сейчас · урок \(n)"))
                    if let u = store.lib.unit(n) {
                        Text(u.ko).font(.title2.weight(.bold))
                        Text(u.title.text(store.state.lang) + " · " + u.grammar.map(\.name).joined(separator: " · ")).font(.footnote).foregroundStyle(Color.muted)
                    }
                }
                Spacer()
                Ring(value: p, label: "\(Int(p * 100))%", size: 64)
            }
            ProgressView(value: p).tint(p >= Store.goal ? .good : .info)
            Text(L.s("90% mastered opens Unit \(min(n + 1, 16)). Cards and role-play use only this unit.", "90% открывает урок \(min(n + 1, 16)). Карточки и диалог — только из этого урока."))
                .font(.caption).foregroundStyle(Color.muted)
            HStack(spacing: 8) {
                Button(L.s("Open unit", "Открыть урок")) { store.tab = .learn }.buttonStyle(GlassButton())
                Button(L.s("Practice", "Тренировать")) { store.launch = .quiz(.cards) }.buttonStyle(PrimaryButton())
            }
        }
        .padding(18).glass()
    }

    // MARK: daily review

    var reviewCard: some View {
        let due = store.dueReview.count
        return HStack(spacing: 14) {
            Image(systemName: "arrow.triangle.2.circlepath").font(.title2).foregroundStyle(Color.pron)
                .frame(width: 48, height: 48).background(Color.pron.opacity(0.15), in: Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text(L.s("Daily review · \(due) due", "Повторение · \(due) к повтору")).font(.headline)
                Text(L.s("Cards from earlier units, right before you'd forget them. Counts toward unlocking.", "Карточки прошлых уроков — до того, как вы их забудете. Засчитывается для разблокировки."))
                    .font(.caption).foregroundStyle(Color.muted)
            }
            Spacer(minLength: 0)
            Button(L.s("Start", "Начать")) { store.launch = .quiz(.review) }.font(.headline).foregroundStyle(Color.pron)
        }
        .padding(16).glass()
    }

    // MARK: this week

    var weekStrip: some View {
        let cal = Calendar.current
        let days = (0..<7).reversed().compactMap { cal.date(byAdding: .day, value: -$0, to: Date()) }
        return Button { store.tab = .calendar } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack { Eyebrow(text: L.s("This week", "Эта неделя")); Spacer(); Image(systemName: "calendar").foregroundStyle(Color.muted) }
                HStack(spacing: 6) {
                    ForEach(days, id: \.self) { d in
                        let log = store.state.activity[Store.dayKey(d)]
                        VStack(spacing: 6) {
                            Text(d.formatted(.dateTime.weekday(.narrow))).font(.caption2).foregroundStyle(Color.muted)
                            Circle().fill(heat(log?.answered ?? 0)).frame(width: 30, height: 30)
                                .overlay(Text("\(cal.component(.day, from: d))").font(.caption2.bold()).foregroundStyle(.white))
                                .overlay(Circle().strokeBorder(cal.isDateInToday(d) ? Color.accent : .clear, lineWidth: 2))
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .padding(16).glass()
        }
        .buttonStyle(.plain)
    }

    // MARK: goal

    var goalCard: some View {
        Button { store.launch = .setup } label: {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Eyebrow(text: L.s("Your goal", "Ваша цель"))
                    Text(store.goalText).font(.headline).foregroundStyle(Color.ink)
                    Text(store.state.intensity.title + " · " + store.state.intensity.detail).font(.footnote).foregroundStyle(Color.muted)
                }
                Spacer()
                Text(dday).font(.system(size: 22, weight: .bold, design: .monospaced))
                    .foregroundStyle(LinearGradient(colors: [.accent2, .info], startPoint: .leading, endPoint: .trailing))
            }
            .padding(16).glass()
        }
        .buttonStyle(.plain)
    }

    var dday: String {
        guard let d = store.daysLeft else { return "›" }
        return d > 0 ? "D-\(d)" : d == 0 ? "D-DAY" : "D+\(-d)"
    }

    // MARK: apps

    var appsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack { Text(L.s("Practice shortcuts", "Тренировочные ярлыки")).font(.title3.bold()); Spacer()
                Button(editingApps ? L.s("Done", "Готово") : L.s("Edit", "Изменить")) { editingApps.toggle() } }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 14), count: 4), spacing: 14) {
                ForEach(Array(store.state.apps.enumerated()), id: \.element.id) { i, a in
                    Button {
                        if editingApps { store.state.apps[i].blocked.toggle() }
                        else if a.blocked { store.showShield(a.name) }
                        else { store.flash(L.s("\(a.name) is not blocked.", "\(a.name) не заблокирован.")) }
                    } label: {
                        VStack(spacing: 6) {
                            ZStack(alignment: .bottomTrailing) {
                                RoundedRectangle(cornerRadius: 15, style: .continuous).fill(Color(hex: a.color))
                                    .frame(width: 58, height: 58)
                                    .overlay(Text(String(a.name.prefix(1))).font(.title2.weight(.heavy)).foregroundStyle(.white))
                                    .saturation(a.blocked ? 0 : 1).opacity(a.blocked ? 0.6 : 1)
                                if a.blocked { Image(systemName: "lock.fill").font(.system(size: 10)).foregroundStyle(.white).padding(5).background(Circle().fill(Color.accent)).offset(x: 5, y: 5) }
                            }
                            .overlay(editingApps ? RoundedRectangle(cornerRadius: 15).strokeBorder(Color.hair, style: StrokeStyle(lineWidth: 2, dash: [5])).padding(-4) : nil)
                            Text(a.name).font(.caption).foregroundStyle(Color.muted).lineLimit(1)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(16).glass()
            Text(L.s("Tapping a tile opens a practice shield inside Unbrick. It does not block Instagram, TikTok, or anything else. Real blocking is Screen Time, below.",
                     "Нажатие открывает тренировочный щит внутри Unbrick и не блокирует Instagram, TikTok и остальные. Настоящая блокировка — это Экранное время ниже."))
                .font(.caption).foregroundStyle(Color.muted)
            Button { store.launch = .blocking } label: {
                Label(store.state.screenTimeReady ? L.s("Real blocking is on (Screen Time)", "Блокировка включена (Экранное время)") : L.s("Turn on real blocking", "Включить настоящую блокировку"),
                      systemImage: store.state.screenTimeReady ? "lock.shield.fill" : "lock.shield")
            }
            .buttonStyle(GlassButton())
        }
    }
}

/// Activity color for a day: none → faint, more cards answered → brighter green.
func heat(_ answered: Int) -> Color {
    switch answered {
    case 0: return Color.white.opacity(0.07)
    case 1..<5: return Color.good.opacity(0.35)
    case 5..<15: return Color.good.opacity(0.6)
    default: return Color.good
    }
}

struct MineSection: View {
    @EnvironmentObject var store: Store
    @State private var ko = ""
    @State private var meaning = ""
    @State private var topic = ""
    @State private var busy = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack { Text(L.s("My cards", "Мои карточки")).font(.title3.bold()); Spacer()
                if !store.state.mine.isEmpty {
                    Button(L.s("Practice \(min(store.state.mine.count, 10))", "Тренировать \(min(store.state.mine.count, 10))")) {
                        store.launch = .practice(UUID(), Array(store.mineCards.shuffled().prefix(10)))
                    }
                } }
            VStack(spacing: 10) {
                TextField(L.s("Korean, e.g. 체류 기간을 연장하고 싶어요", "По-корейски, напр. 체류 기간을 연장하고 싶어요"), text: $ko).field()
                HStack {
                    TextField(L.s("Meaning", "Значение"), text: $meaning).field()
                    Button(L.s("Add", "Добавить")) {
                        store.state.mine.append(MineCard(id: UUID().uuidString, t: ko, m: meaning)); ko = ""; meaning = ""
                        store.flash(L.s("Card added", "Карточка добавлена"))
                    }
                    .buttonStyle(PrimaryButton()).frame(width: 100).disabled(ko.isEmpty || meaning.isEmpty)
                }
                if AI.available {
                    Divider().overlay(Color.hair)
                    HStack {
                        TextField(L.s("Ask AI: e.g. 귀화 면접, renting", "Попросите ИИ: напр. 귀화 면접, аренда"), text: $topic).field()
                        Button { generate() } label: { busy ? AnyView(ProgressView()) : AnyView(Text(L.s("Generate", "Создать"))) }
                            .buttonStyle(GlassButton()).frame(width: 110).disabled(topic.isEmpty || busy)
                    }
                }
                ForEach(store.state.mine.reversed()) { c in
                    HStack {
                        VStack(alignment: .leading) { Text(c.t).bold(); Text(c.m).font(.footnote).foregroundStyle(Color.muted) }
                        Spacer()
                        IconButton(system: "speaker.wave.2.fill", size: 34) { Speaker.shared.say(c.t) }
                        Button { store.state.mine.removeAll { $0.id == c.id } } label: { Image(systemName: "xmark").foregroundStyle(Color.muted) }
                    }
                    .padding(.vertical, 4)
                }
            }
            .padding(16).glass()
        }
    }

    func generate() {
        busy = true
        let lang = store.state.lang == .ru ? "Russian" : "English", u = store.lib.unit(store.state.unit)
        let system = "You write Korean speaking flashcards for a learner (native language \(lang); goal: \(store.goalText); studying KIIP 중급 1 unit \(u?.n ?? 3) \"\(u?.ko ?? "")\" with grammar \(u?.grammar.map(\.name).joined(separator: ", ") ?? "")). Sentences they would really SAY in Korea, polite style, under 14 words, using the unit's grammar where natural. Facts about Korea must be accurate. m is the \(lang) meaning."
        Task { @MainActor in
            do {
                let cards = try await AI.cards(system: system, prompt: "Write 8 cards about: \(topic.prefix(120))")
                let have = Set(store.state.mine.map { Grader.normalized($0.t) })
                let new = cards.map { MineCard(id: UUID().uuidString, t: $0.s("t"), m: $0.s("m")) }
                    .filter { !$0.t.isEmpty && !have.contains(Grader.normalized($0.t)) }
                store.state.mine += new
                store.flash(L.s("Added \(new.count) cards.", "Добавлено карточек: \(new.count)."))
                topic = ""
            } catch { store.flash(error.localizedDescription) }
            busy = false
        }
    }
}

extension View {
    func field() -> some View {
        self.padding(12).background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14)).overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.hair))
    }
}
