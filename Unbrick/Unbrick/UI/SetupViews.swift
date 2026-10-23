import SwiftUI

struct SetupView: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) var dismiss
    var isEdit: Bool
    @State private var draft = AppState()
    @State private var hasDate = false
    @State private var date = Date().addingTimeInterval(60 * 86400)

    var body: some View {
        ZStack {
            AuroraBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if isEdit {
                        Button { dismiss() } label: { Image(systemName: "xmark").font(.title3.weight(.semibold)).foregroundStyle(Color.muted) }
                            .accessibilityLabel(t("Close", "Закрыть"))
                    }
                    step(1); Text(draft.lang == .ru ? "Ваш родной язык?" : "What's your native language?").font(.title.weight(.heavy))
                    HStack(spacing: 10) {
                        choice("English", "Meanings & feedback in English", draft.lang == .en) { draft.lang = .en }
                        choice("Русский", "Значения и разбор по-русски", draft.lang == .ru) { draft.lang = .ru }
                    }
                    step(2)
                    Text(t("What are you working toward in Korea?", "К чему вы готовитесь в Корее?")).font(.title.weight(.heavy))
                    ForEach(Track.allCases, id: \.self) { tr in
                        choice(tr.title, tr.detail, draft.track == tr) { draft.track = tr }
                    }
                    Text(t("KIIP level", "Уровень KIIP")).font(.headline)
                    Picker(t("KIIP level", "Уровень KIIP"), selection: $draft.level) {
                        ForEach(Levels.all, id: \.self) { lv in
                            Text(Levels.line(lv, draft.lang)).tag(lv)
                        }
                    }
                    .pickerStyle(.menu).labelsHidden()
                    Text(t("Current unit", "Текущий урок")).font(.headline)
                    Picker(t("Current unit", "Текущий урок"), selection: $draft.unit) {
                        ForEach(store.lib.units(for: draft.level)) { u in
                            Text("\(u.n) · \(u.ko) · \(draft.lang == .ru ? u.ru : u.en)").tag(u.n)
                        }
                    }
                    .pickerStyle(.menu).labelsHidden().frame(maxWidth: .infinity, alignment: .leading).padding(8).glass(14)
                    if store.lib.units(for: draft.level).isEmpty {
                        Text(t("This level has no lessons yet.", "На этом уровне пока нет уроков."))
                            .font(.footnote).foregroundStyle(Color.muted)
                    }
                    Toggle(t("I have an exam, interview or visa date", "У меня есть дата экзамена, собеседования или визы"), isOn: $hasDate).tint(.accent)
                    if hasDate { DatePicker("", selection: $date, displayedComponents: .date).datePickerStyle(.compact).labelsHidden() }
                    step(3); Text(t("How hard should unlocking be?", "Насколько сложной должна быть разблокировка?")).font(.title.weight(.heavy))
                    ForEach(Intensity.allCases, id: \.self) { i in
                        choice(i.title, i.detail, draft.intensity == i) { draft.intensity = i }
                    }
                    Button(isEdit ? t("Save", "Сохранить") : t("Continue", "Продолжить")) {
                        var s = store.state
                        s.lang = draft.lang; s.track = draft.track; s.level = draft.level; s.unit = draft.unit
                        s.intensity = draft.intensity; s.date = hasDate ? date : nil; s.setupDone = true
                        store.state = s
                        store.setLevel(draft.level)
                        dismiss()
                    }
                    .buttonStyle(PrimaryButton()).padding(.top, 8)
                }
                .padding(.horizontal, 16).padding(.vertical, 20)
            }
            .scrollIndicators(.hidden)
        }
        .onAppear {
            draft = store.state
            if let d = store.state.date { hasDate = true; date = d }
            clampUnit()
        }
        .onChange(of: draft.level) { _, _ in clampUnit() }
    }

    func clampUnit() {
        let numbers = store.lib.units(for: draft.level).map(\.n)
        if !numbers.contains(draft.unit) { draft.unit = numbers.min() ?? 1 }
    }

    func t(_ en: String, _ ru: String) -> String { draft.lang == .ru ? ru : en }
    func step(_ n: Int) -> some View { Eyebrow(text: t("Set up · \(n) of 3", "Настройка · \(n) из 3")) }

    func choice(_ title: String, _ detail: String, _ on: Bool, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.headline).foregroundStyle(Color.ink)
                Text(detail).font(.footnote).foregroundStyle(Color.muted)
            }
            .frame(maxWidth: .infinity, alignment: .leading).padding(14).glass(18)
            .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(on ? Color.accent : .clear, lineWidth: 2))
        }
        .buttonStyle(.plain)
    }
}

struct ShieldView: View {
    @EnvironmentObject var store: Store
    var app: String
    var onCards: () -> Void
    var onRole: () -> Void
    var onTutor: () -> Void
    var onClose: () -> Void

    var body: some View {
        ZStack {
            AuroraBackground()
            VStack(spacing: 18) {
                Spacer()
                Image(systemName: "lock.fill").font(.system(size: 34)).foregroundStyle(.white)
                    .frame(width: 88, height: 88).background(Circle().fill(brandGradient)).shadow(color: .accent.opacity(0.6), radius: 30)
                Text(L.s("Practice lock", "Тренировочный замок")).font(.largeTitle.weight(.heavy)).multilineTextAlignment(.center)
                let it = store.state.intensity
                Text(L.s("This screen is inside Unbrick. It does not close \(app). Speak Korean to run the unlock timer for \(it.minutes) minutes: \(it.pass) of \(it.cards) cards, a role-play, or \(it.tutor) good answers to your tutor.",
                         "Этот экран внутри Unbrick и не закрывает \(app). Говорите по-корейски, чтобы запустить таймер на \(it.minutes) мин: \(it.pass) из \(it.cards) карточек, диалог или \(it.tutor) хороших ответа репетитору."))
                    .multilineTextAlignment(.center).foregroundStyle(Color.muted).padding(.horizontal, 12)
                Spacer()
                Button(L.s("Cards", "Карточки"), action: onCards).buttonStyle(PrimaryButton())
                Button(L.s("Role-play", "Диалог"), action: onRole).buttonStyle(GlassButton())
                Button(L.s("AI tutor", "ИИ-репетитор"), action: onTutor).buttonStyle(GlassButton())
                Button(L.s("Not now", "Не сейчас"), action: onClose).foregroundStyle(Color.muted).padding(.top, 4)
            }
            .padding(24)
        }
    }
}

