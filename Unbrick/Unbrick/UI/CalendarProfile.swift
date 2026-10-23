import SwiftUI

struct CalendarView: View {
    @EnvironmentObject var store: Store
    @State private var month = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: Date()))!
    @State private var selected = Date()
    private let cal = Calendar.current

    var body: some View {
        ZStack {
            AuroraBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text(L.s("Calendar", "Календарь")).font(.largeTitle.weight(.heavy)).padding(.top, 8)
                    summary
                    monthGrid
                    dayDetail
                    if let d = store.state.date {
                        HStack {
                            Image(systemName: "flag.checkered").foregroundStyle(Color.gram)
                            Text(L.s("Exam / interview: ", "Экзамен / собеседование: ") + d.formatted(date: .long, time: .omitted)).font(.subheadline)
                            Spacer()
                            if let left = store.daysLeft { Text(left >= 0 ? "D-\(left)" : "D+\(-left)").font(.headline.monospaced()).foregroundStyle(Color.gram) }
                        }
                        .padding(14).glass()
                    }
                }
                .padding(.horizontal, 16).padding(.bottom, 30)
            }
            .scrollIndicators(.hidden)
        }
    }

    var summary: some View {
        let logs = store.state.activity.values
        let days = logs.filter { $0.answered > 0 }.count
        let total = logs.reduce(0) { $0 + $1.answered }, unlocks = logs.reduce(0) { $0 + $1.unlocks }
        return HStack(spacing: 10) {
            tile("🔥 \(store.state.streak)", L.s("Day streak", "Дней подряд"))
            tile("\(days)", L.s("Study days", "Дней учёбы"))
            tile("\(total)", L.s("Cards", "Карточек"))
            tile("\(unlocks)", L.s("Unlocks", "Разблок."))
        }
    }

    func tile(_ v: String, _ k: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(v).font(.system(size: 18, weight: .bold, design: .monospaced)).lineLimit(1).minimumScaleFactor(0.7)
            Text(k).font(.caption2).foregroundStyle(Color.muted).lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(10).glass(14)
    }

    var monthGrid: some View {
        let first = month
        let range = cal.range(of: .day, in: .month, for: first)!
        let lead = (cal.component(.weekday, from: first) - cal.firstWeekday + 7) % 7
        let cells: [Date?] = Array(repeating: nil, count: lead) + range.map { cal.date(byAdding: .day, value: $0 - 1, to: first) }
        let symbols = cal.veryShortStandaloneWeekdaySymbols
        let ordered = Array(symbols[(cal.firstWeekday - 1)...] + symbols[..<(cal.firstWeekday - 1)])
        return VStack(spacing: 12) {
            HStack {
                Button { month = cal.date(byAdding: .month, value: -1, to: month)! } label: { Image(systemName: "chevron.left") }
                Spacer()
                Text(month.formatted(.dateTime.year().month(.wide))).font(.headline)
                Spacer()
                Button { month = cal.date(byAdding: .month, value: 1, to: month)! } label: { Image(systemName: "chevron.right") }
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 6) {
                ForEach(Array(ordered.enumerated()), id: \.offset) { _, s in Text(s).font(.caption2).foregroundStyle(Color.muted) }
                ForEach(Array(cells.enumerated()), id: \.offset) { _, d in
                    if let d {
                        let log = store.state.activity[Store.dayKey(d)]
                        let isExam = store.state.date.map { cal.isDate($0, inSameDayAs: d) } ?? false
                        Button { selected = d } label: {
                            Text("\(cal.component(.day, from: d))").font(.caption.bold()).foregroundStyle(.white)
                                .frame(maxWidth: .infinity, minHeight: 38)
                                .background(RoundedRectangle(cornerRadius: 10).fill(isExam ? Color.gram.opacity(0.7) : heat(log?.answered ?? 0)))
                                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(cal.isDate(d, inSameDayAs: selected) ? Color.white : cal.isDateInToday(d) ? Color.accent : .clear, lineWidth: 1.5))
                                .overlay(alignment: .topTrailing) {
                                    if (log?.unlocks ?? 0) > 0 { Image(systemName: "lock.open.fill").font(.system(size: 7)).foregroundStyle(.white).padding(3) }
                                }
                        }
                        .buttonStyle(.plain)
                    } else { Color.clear.frame(height: 38) }
                }
            }
            HStack(spacing: 6) {
                Text(L.s("Less", "Меньше")).font(.caption2).foregroundStyle(Color.muted)
                ForEach([0, 2, 8, 20], id: \.self) { RoundedRectangle(cornerRadius: 3).fill(heat($0)).frame(width: 14, height: 14) }
                Text(L.s("More", "Больше")).font(.caption2).foregroundStyle(Color.muted)
                Spacer()
                RoundedRectangle(cornerRadius: 3).fill(Color.gram.opacity(0.7)).frame(width: 14, height: 14)
                Text(L.s("Exam", "Экзамен")).font(.caption2).foregroundStyle(Color.muted)
            }
        }
        .padding(16).glass()
    }

    var dayDetail: some View {
        let log = store.state.activity[Store.dayKey(selected)] ?? DayLog()
        return VStack(alignment: .leading, spacing: 8) {
            Text(selected.formatted(date: .complete, time: .omitted)).font(.headline)
            if log.answered == 0 {
                Text(L.s("No practice this day.", "В этот день занятий не было.")).foregroundStyle(Color.muted)
            } else {
                Text(L.s("\(log.correct) of \(log.answered) cards right · \(log.unlocks) unlock(s)", "Верно \(log.correct) из \(log.answered) · разблокировок: \(log.unlocks)"))
                if !log.units.isEmpty {
                    Text(L.s("Units: ", "Уроки: ") + log.units.sorted().map { "\($0) \(store.lib.unit($0)?.ko ?? "")" }.joined(separator: " · "))
                        .font(.footnote).foregroundStyle(Color.muted)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(16).glass()
    }
}

struct ProfileView: View {
    @EnvironmentObject var store: Store
    @State private var showPrivacy = false

    var body: some View {
        ZStack {
            AuroraBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(L.s("Profile", "Профиль")).font(.largeTitle.weight(.heavy)).padding(.top, 8)
                    progress
                    Button(L.s("Review all material", "Повторить весь материал")) { store.launch = .review }.buttonStyle(PrimaryButton())
                    section(L.s("Goal & difficulty", "Цель и сложность")) {
                        Text(store.goalText).font(.headline)
                        Text(store.state.intensity.title + " · " + store.state.intensity.detail).font(.footnote).foregroundStyle(Color.muted)
                        Button(L.s("Change goal", "Изменить цель")) { store.launch = .setup }.buttonStyle(GlassButton())
                    }
                    section(L.s("Native language", "Родной язык")) {
                        Picker("", selection: $store.state.lang) { Text("English").tag(Lang.en); Text("Русский").tag(Lang.ru) }.pickerStyle(.segmented)
                    }
                    section(L.s("AI checking", "ИИ-проверка")) {
                        HStack {
                            Text(L.s("Checking with: ", "Проверяет: ") + AI.engineName).font(.subheadline.weight(.semibold))
                            Spacer()
                            Image(systemName: AI.available ? "checkmark.seal.fill" : "exclamationmark.triangle.fill").foregroundStyle(AI.available ? Color.good : .pron)
                        }
                        Text(aiBlurb).font(.footnote).foregroundStyle(Color.muted)
                        Button(L.s("Privacy policy", "Политика конфиденциальности")) { showPrivacy = true }.buttonStyle(GlassButton())
                    }
                    section(L.s("Korean voice", "Корейский голос")) {
                        Text(Speaker.shared.voiceDescription).font(.subheadline.weight(.semibold))
                        Text(L.s("For natural Korean: Settings › Accessibility › Spoken Content › Voices › Korean › Yuna (Premium).",
                                 "Для естественного корейского: Настройки › Универсальный доступ › Устный контент › Голоса › Корейский › Yuna (улучшенный)."))
                            .font(.footnote).foregroundStyle(Color.muted)
                        Button(L.s("Test voice", "Проверить голос")) { Speaker.shared.say("안녕하세요. 사회통합프로그램 중급 1 과정에 오신 것을 환영합니다.") }.buttonStyle(GlassButton())
                    }
                    section(L.s("Blocking", "Блокировка")) {
                        Label(store.state.screenTimeReady ? L.s("Screen Time blocking is on", "Блокировка Экранным временем включена") : L.s("Not set up yet", "Ещё не настроена"),
                              systemImage: store.state.screenTimeReady ? "lock.shield.fill" : "lock.shield")
                        Button(L.s("Blocking setup", "Настройка блокировки")) { store.launch = .blocking }.buttonStyle(GlassButton())
                    }
                }
                .padding(.horizontal, 16).padding(.bottom, 30)
            }
            .scrollIndicators(.hidden)
        }
        .sheet(isPresented: $showPrivacy) { PrivacyView() }
    }

    var aiBlurb: String {
        if ProxyConfig.isConfigured {
            return L.s("Spoken and typed answers are sent to Unbrick's server so Claude can reply. The server does not keep them. Your Anthropic key is not on this phone.",
                       "Произнесённые и написанные ответы уходят на сервер Unbrick, чтобы ответил Claude. Сервер их не хранит. Ключ Anthropic на телефоне не хранится.")
        }
        return L.s("This build has no Unbrick server yet, so Claude is off. Apple Intelligence on this iPhone can still check answers when it is turned on. Nothing you say is sent to Anthropic.",
                   "В этой сборке сервер Unbrick ещё не указан, поэтому Claude выключен. Apple Intelligence на этом iPhone может проверять ответы, если он включён. Anthropic ничего не получает.")
    }

    var progress: some View {
        let items = store.allItems, st = items.map { store.srs($0.id) }
        let n = st.reduce(0) { $0 + $1.n }, ok = st.reduce(0) { $0 + $1.ok }
        let pron = items.filter { $0.kind == .pron || $0.kind == .line }.compactMap { store.srs($0.id).last }
        return VStack(spacing: 10) {
            HStack(spacing: 18) {
                Ring(value: store.coursePct, label: "\(Int(store.coursePct * 100))%")
                VStack(alignment: .leading, spacing: 4) {
                    Eyebrow(text: L.s("Level 3 course · goal 90%", "Курс уровня 3 · цель 90%"))
                    Text(L.s("\(store.masteredCount) of \(store.lib.book.count) cards mastered", "Освоено \(store.masteredCount) из \(store.lib.book.count)")).font(.headline)
                    Text(L.s("Unit \(store.state.unit) · \(store.state.xp) xp · \(store.state.streak)-day streak", "Урок \(store.state.unit) · \(store.state.xp) xp · \(store.state.streak) дн. подряд"))
                        .font(.footnote).foregroundStyle(Color.muted)
                }
                Spacer()
            }
            .padding(16).glass()
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                tile("\(st.filter { $0.n > 0 }.count)", L.s("Cards seen", "Пройдено карточек"), .ink)
                tile(n > 0 ? "\(ok * 100 / n)%" : "—", L.s("Accuracy", "Точность"), .good)
                tile(pron.isEmpty ? "—" : "\(pron.reduce(0, +) / pron.count)%", L.s("Avg. pronunciation", "Ср. произношение"), .pron)
                tile("\(store.state.tutorOk)/\(store.state.tutorQ)", L.s("Tutor answers right", "Верно репетитору"), .info)
            }
            VStack(alignment: .leading, spacing: 8) {
                Eyebrow(text: L.s("Units", "Уроки"))
                ForEach(store.lib.units) { u in
                    HStack(spacing: 8) {
                        Text("\(u.n)").font(.caption.monospaced()).foregroundStyle(Color.muted).frame(width: 20, alignment: .trailing)
                        Text(u.ko).font(.caption).frame(width: 96, alignment: .leading).lineLimit(1)
                        ProgressView(value: store.unitPct(u.n)).tint(store.unitPct(u.n) >= Store.goal ? .good : .info)
                        Text("\(Int(store.unitPct(u.n) * 100))%").font(.caption2.monospaced()).foregroundStyle(Color.muted).frame(width: 34, alignment: .trailing)
                    }
                }
            }
            .padding(16).glass()
        }
    }

    func tile(_ v: String, _ k: String, _ c: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(v).font(.system(size: 22, weight: .bold, design: .monospaced)).foregroundStyle(c)
            Text(k).font(.caption).foregroundStyle(Color.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(14).glass(18)
    }

    func section<C: View>(_ title: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Eyebrow(text: title)
            content()
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading).glass()
    }
}
