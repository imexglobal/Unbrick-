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
                    if isEdit { Button { dismiss() } label: { Image(systemName: "xmark").font(.title3.weight(.semibold)).foregroundStyle(Color.muted) } }
                    step(1); Text(draft.lang == .ru ? "Ваш родной язык?" : "What's your native language?").font(.title.weight(.heavy))
                    HStack(spacing: 10) {
                        choice("English", "Meanings & feedback in English", draft.lang == .en) { draft.lang = .en }
                        choice("Русский", "Значения и разбор по-русски", draft.lang == .ru) { draft.lang = .ru }
                    }
                    step(2); Text(t("What are you working toward in Korea?", "К чему вы готовитесь в Корее?")).font(.title.weight(.heavy))
                    ForEach(Track.allCases, id: \.self) { tr in
                        choice(tr.title, tr.detail, draft.track == tr) { draft.track = tr }
                    }
                    Text(t("KIIP level you're studying", "Уровень KIIP, который вы изучаете")).font(.headline)
                    Picker("", selection: $draft.level) { ForEach(0...5, id: \.self) { Text("\($0)").tag($0) } }.pickerStyle(.segmented)
                    Text(t("Which Level 3 unit are you on?", "Какой урок 3-го уровня проходите?")).font(.headline)
                    Picker("", selection: $draft.unit) {
                        ForEach(store.lib.units) { u in Text("\(u.n) · \(u.ko) · \(draft.lang == .ru ? u.ru : u.en)").tag(u.n) }
                    }
                    .pickerStyle(.menu).tint(.ink).frame(maxWidth: .infinity, alignment: .leading).padding(8).glass(14)
                    Toggle(t("I have an exam, interview or visa date", "У меня есть дата экзамена, собеседования или визы"), isOn: $hasDate).tint(.accent)
                    if hasDate { DatePicker("", selection: $date, displayedComponents: .date).datePickerStyle(.compact).labelsHidden() }
                    step(3); Text(t("How hard should unlocking be?", "Насколько сложной должна быть разблокировка?")).font(.title.weight(.heavy))
                    ForEach(Intensity.allCases, id: \.self) { i in
                        choice(i.title, i.detail, draft.intensity == i) { draft.intensity = i }
                    }
                    Button(isEdit ? t("Save", "Сохранить") : t("Start blocking", "Начать блокировку")) {
                        var s = store.state
                        s.lang = draft.lang; s.track = draft.track; s.level = draft.level; s.unit = draft.unit
                        s.intensity = draft.intensity; s.date = hasDate ? date : nil; s.setupDone = true
                        store.state = s
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
        }
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
                Text(L.s("\(app) is bricked", "\(app) заблокирован")).font(.largeTitle.weight(.heavy)).multilineTextAlignment(.center)
                let it = store.state.intensity
                Text(L.s("Speak Korean to open it for \(it.minutes) minutes: \(it.pass) of \(it.cards) cards, a role-play, or \(it.tutor) good answers to your tutor.",
                         "Говорите по-корейски, чтобы открыть на \(it.minutes) мин: \(it.pass) из \(it.cards) карточек, диалог или \(it.tutor) хороших ответа репетитору."))
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

