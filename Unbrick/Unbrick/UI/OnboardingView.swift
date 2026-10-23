import SwiftUI

/// First launch: language, then a level or a six-question placement test.
/// Intensity, exam date and track stay on Profile → Change goal.
struct OnboardingView: View {
    @EnvironmentObject var store: Store
    @State private var lang: Lang = .en
    @State private var step = 0
    @State private var index = 0
    @State private var correct = 0
    @State private var suggested = 0

    var body: some View {
        ZStack {
            AuroraBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Unbrick").font(.title2.weight(.heavy)).padding(.top, 12)
                    switch step {
                    case 0: language
                    case 1: pickLevel
                    case 2: question
                    default: result
                    }
                }
                .padding(.horizontal, 16).padding(.bottom, 28)
            }
            .scrollIndicators(.hidden)
        }
    }

    func t(_ en: String, _ ru: String) -> String { lang == .ru ? ru : en }

    var language: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(t("What's your native language?", "Ваш родной язык?")).font(.largeTitle.weight(.heavy))
            Text(t("Meanings, feedback and this setup follow the language you pick. You can change it later in Profile.",
                   "Значения, разбор и эта настройка идут на выбранном языке. Позже его можно сменить в Профиле."))
                .foregroundStyle(Color.muted)
            choice("English", "Meanings and feedback in English", lang == .en) { lang = .en }
            choice("Русский", "Значения и разбор по-русски", lang == .ru) { lang = .ru }
            Button(t("Continue", "Продолжить")) { step = 1 }.buttonStyle(PrimaryButton()).padding(.top, 8)
        }
    }

    var pickLevel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(t("Where do you want to start?", "С чего начать?")).font(.largeTitle.weight(.heavy))
            Text(t("Pick a KIIP level, or take a short placement test. You can change the level any time on Learn.",
                   "Выберите уровень KIIP или пройдите короткий тест. Уровень можно сменить в разделе Учёба."))
                .foregroundStyle(Color.muted)
            ForEach(Levels.all, id: \.self) { lv in
                Button { finish(lv) } label: {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(Levels.line(lv, lang)).font(.headline).foregroundStyle(Color.ink)
                        Text(levelHint(lv)).font(.footnote).foregroundStyle(Color.muted)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading).padding(14).glass(18)
                }
                .buttonStyle(.plain)
                .accessibilityHint(t("Starts this level at unit 1", "Начинает этот уровень с урока 1"))
            }
            Button(t("Not sure? Take a placement test", "Не уверены? Пройти тест")) {
                index = 0; correct = 0; step = 2
            }
            .buttonStyle(GlassButton())
        }
    }

    func levelHint(_ lv: Int) -> String {
        switch lv {
        case 0: return t("Hangul and first sentences.", "Хангыль и первые фразы.")
        case 1: return t("Daily life: family, food, transport.", "Быт: семья, еда, транспорт.")
        case 2: return t("Plans, reasons, errands, manners.", "Планы, причины, дела, этикет.")
        case 3: return t("Intermediate 1, the original course.", "Средний 1, исходный курс.")
        case 4: return t("Life in Korea, society and work.", "Жизнь в Корее, общество и работа.")
        default: return t("How Korea works: law, history, civics.", "Как устроена Корея: право, история, общество.")
        }
    }

    var question: some View {
        let item = Placement.questions[index]
        return VStack(alignment: .leading, spacing: 14) {
            Eyebrow(text: t("Placement · \(index + 1) of \(Placement.questions.count)", "Тест · \(index + 1) из \(Placement.questions.count)"))
            Text(lang == .ru ? item.promptRu : item.prompt).font(.title2.weight(.bold))
            let choices = lang == .ru ? item.choicesRu : item.choices
            ForEach(Array(choices.enumerated()), id: \.offset) { i, choice in
                Button {
                    let next = correct + (i == item.answer ? 1 : 0)
                    correct = next
                    if index + 1 >= Placement.questions.count {
                        suggested = Placement.level(forCorrect: next)
                        step = 3
                    } else {
                        index += 1
                    }
                } label: {
                    Text(choice).font(.headline).foregroundStyle(Color.ink)
                        .frame(maxWidth: .infinity, alignment: .leading).padding(14).glass(18)
                }
                .buttonStyle(.plain)
            }
        }
    }

    var result: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(t("Start here", "Начните здесь")).font(.largeTitle.weight(.heavy))
            Text(Levels.line(suggested, lang)).font(.title3.weight(.bold))
            Text(t("\(correct) of \(Placement.questions.count) correct. This is a starting point, not an exam score. You can pick another level.",
                   "Верно \(correct) из \(Placement.questions.count). Это точка старта, а не оценка экзамена. Можно выбрать другой уровень."))
                .foregroundStyle(Color.muted)
            Button(t("Start \(Levels.ko(suggested))", "Начать \(Levels.ko(suggested))")) { finish(suggested) }
                .buttonStyle(PrimaryButton())
            Button(t("Choose a different level", "Выбрать другой уровень")) { step = 1 }
                .buttonStyle(GlassButton())
        }
    }

    func finish(_ level: Int) {
        store.state.lang = lang
        store.state.track = .kiip
        store.state.intensity = .steady
        store.state.setupDone = true
        store.setLevel(level)
    }

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
        .accessibilityAddTraits(on ? AccessibilityTraits.isSelected : AccessibilityTraits())
    }
}
