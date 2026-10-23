import SwiftUI

enum QuizMode: Equatable { case cards, role(Int), practice, review }

struct Feedback {
    var ok: Bool
    var title: String? = nil
    var heard: String? = nil
    var pct: Int? = nil
    var diffTarget: String? = nil
    var answer: String? = nil        // marked-up Korean to show and play
    var meaning: String? = nil
    var tips: [(TipKind, String, String)] = []
    var mistakes: [Mistake] = []
    var note: String? = nil
    var voice = false
}

final class QuizModel: ObservableObject {
    let mode: QuizMode
    @Published var cards: [Card]
    @Published var index = 0
    @Published var results: [Bool?]
    @Published var feedback: Feedback?
    @Published var checking = false
    @Published var selfCheck = false
    @Published var options: [String] = []
    @Published var picked: String?
    var store: Store { .shared }

    init(mode: QuizMode, cards: [Card]) {
        self.mode = mode
        self.cards = cards
        self.results = Array(repeating: nil, count: cards.count)
        prepare()
    }

    var done: Bool { index >= cards.count }
    var card: Card { cards[min(index, cards.count - 1)] }
    var progress: Double { cards.isEmpty ? 0 : Double(index) / Double(cards.count) }
    var right: Int { results.compactMap { $0 }.filter { $0 }.count }
    var need: Int {
        let it = store.state.intensity
        if case .role = mode { return Int((Double(cards.count) * Double(it.pass) / Double(it.cards)).rounded(.up)) }
        if mode == .review { return min(it.pass, max(1, cards.count - 1)) }
        return it.pass
    }
    var passed: Bool { right >= need }

    func prepare() {
        feedback = nil; selfCheck = false; picked = nil; checking = false
        guard !done else { return }
        let c = card
        if c.kind == .listen {
            let pool = store.pool().filter { $0.question == nil && $0.id != c.id }.shuffled().prefix(3).map { $0.meaning.text(L.lang) }
            options = ([c.meaning.text(L.lang)] + pool).shuffled()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { Speaker.shared.say(c.text) }
        } else if c.kind == .line, let p = c.prev {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { Speaker.shared.say(p.ko) }
        } else if let q = c.question {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { Speaker.shared.say(q) }
        }
    }

    // MARK: answering

    func choose(_ option: String) {
        guard picked == nil else { return }
        picked = option
        let ok = option == card.meaning.text(L.lang)
        feedback = Feedback(ok: ok, title: ok ? nil : L.s("Correct answer", "Правильный ответ"), answer: card.text, meaning: card.meaning.text(L.lang))
        if !ok { Speaker.shared.say(card.text) }
    }

    func heard(_ alts: [String]) {
        guard !alts.isEmpty else { return }
        let c = card
        var best = -1.0, said = alts[0]
        for a in alts { let s = Grader.score(c, said: a); if s > best { best = s; said = a } }
        let pct = Int((best * 100).rounded())

        switch c.kind {
        case .word:
            var f = Feedback(ok: best >= 0.7, heard: said, pct: pct, diffTarget: c.plain, answer: c.text, meaning: c.meaning.text(L.lang), voice: true)
            if let ex = c.example { f.tips.append((.info, L.s("Example", "Пример"), ex.ko + "\n" + Meaning(en: ex.en, ru: ex.ru).text(L.lang))) }
            show(f)
        case .gram:
            let parts = Markup.grammarParts(c.text).filter { Grader.syllables($0).count >= 2 }
            let n = Grader.normalized(said)
            let gramHeard = parts.allSatisfy { n.contains(Grader.normalized($0)) }
            var f = Feedback(ok: best >= 0.75 && gramHeard, heard: said, pct: pct, diffTarget: c.plain, answer: c.text, meaning: c.meaning.text(L.lang), voice: true)
            if !gramHeard {
                f.tips.append((.gram, L.s("Grammar", "Грамматика") + " · " + (c.gname ?? ""),
                               L.s("The grammar part didn't come through. Say it clearly: ", "Грамматическая часть не прозвучала. Скажите чётко: ") + parts.joined(separator: " … ")))
            }
            show(f)
        case .form:
            var f = Feedback(ok: best >= 0.8, heard: said, pct: pct, diffTarget: c.plain, answer: c.text, meaning: c.meaning.text(L.lang), voice: true)
            if let g = store.lib.grammarInfo(for: c) {
                let how = L.lang == .ru ? (g.howRu ?? g.ru) : (g.howEn ?? g.en)
                f.tips.append((.gram, L.s("How to form", "Как образовать") + " · " + g.name, how))
            }
            show(f)
        case .pron, .line:
            var f = Feedback(ok: best >= 0.75, heard: said, pct: pct, diffTarget: c.plain, answer: c.text, voice: true)
            let hit = Grader.hits(target: c.plain, said: said).count, total = Grader.syllables(c.plain).count
            f.note = hit == total ? L.s("Every syllable came through clearly.", "Все слоги прозвучали чётко.")
                                  : L.s("Red syllables didn't come through clearly. Play them slowly and repeat.", "Красные слоги прозвучали неясно. Послушайте медленно и повторите.")
            let missed = Grader.missedPron(c, said: said)
            if let u = c.unit.flatMap(store.lib.unit), !Markup.pronWords(c.text).isEmpty {
                let words = (missed.isEmpty ? Markup.pronWords(c.text) : missed).map { "\($0.0) → [\($0.1)]" }.joined(separator: " · ")
                f.tips.append((.pron, L.s("Pronunciation", "Произношение") + " · " + u.pron.rule,
                               words + (missed.isEmpty ? "" : "\n" + Meaning(en: u.pron.en, ru: u.pron.ru).text(L.lang))))
            }
            show(f)
        default:
            judgeWithAI(said: said, best: best)
        }
    }

    /// Without any AI, an interview answer passes if it's a full polite Korean sentence (it's about *your* life, so it can't match the sample).
    private func localOpenCheck(_ said: String) -> Bool {
        let s = said.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: ".?!"))
        let hangul = s.unicodeScalars.filter { (0xAC00...0xD7A3).contains($0.value) }.count
        return hangul >= 4 && ["다", "요", "까"].contains(where: { s.hasSuffix($0) })
    }

    private func judgeWithAI(said: String, best: Double) {
        let c = card
        guard AI.available else {
            let ok = c.kind == .open ? localOpenCheck(said) : best >= 0.72
            var f = Feedback(ok: ok, heard: said, pct: c.kind == .open ? nil : Int(best * 100), diffTarget: c.kind == .open ? nil : c.plain,
                             answer: c.text, meaning: c.meaning.text(L.lang), voice: true)
            f.note = c.kind == .open ? L.s("Sample answer — yours can differ.", "Пример ответа — ваш может отличаться.") : nil
            f.tips.append((.info, L.s("AI checking is off", "ИИ-проверка выключена"), AI.unavailableReason))
            show(f)
            return
        }
        checking = true
        let lang = L.lang == .ru ? "Russian" : "English"
        let task = c.question.map { "Question: \($0)" } ?? "Task: say in Korean: \"\(c.meaning.text(L.lang))\""
        let prompt = """
        \(task)
        \(c.kind == .open ? "Personal interview question: any truthful, relevant answer in a full polite sentence is fine. Sample answer" : "Model answer"): \(c.plain)
        Learner said (speech recognition, may contain small transcription errors): \(said)
        """
        let system = """
        You grade spoken Korean for a learner whose native language is \(lang) and whose goal is \(store.goalText) (KIIP 사회통합프로그램, Korean immigration and naturalization).
        Judge what they most likely said. Mark correct if it is understandable, natural enough for KIIP level 3-5, and \(c.kind == .open ? "answers the question" : "means the same or is factually right").
        Minor particle or ending slips can still be correct, but list them in mistakes. Write feedback, why and grammar in \(lang). fix is a natural corrected Korean sentence (or empty).
        """
        Task { @MainActor in
            do {
                let r = try await AI.judge(system: system, prompt: prompt)
                guard !self.done, self.card.id == c.id else { return }
                var f = Feedback(ok: (r["correct"] as? Bool) == true, heard: said, answer: r.s("fix").isEmpty ? c.text : r.s("fix"), meaning: c.meaning.text(L.lang), voice: true)
                f.note = r.s("feedback")
                f.mistakes = r.mistakes
                if !r.s("grammar").isEmpty { f.tips.append((.gram, L.s("Grammar", "Грамматика"), r.s("grammar"))) }
                self.show(f)
            } catch {
                let ok = c.kind == .open ? self.localOpenCheck(said) : best >= 0.72
                self.show(Feedback(ok: ok, heard: said, pct: c.kind == .open ? nil : Int(best * 100), diffTarget: c.kind == .open ? nil : c.plain,
                                   answer: c.text, meaning: c.meaning.text(L.lang), note: error.localizedDescription, voice: true))
            }
        }
    }

    private func show(_ f: Feedback) {
        checking = false
        feedback = f
        if !f.ok { Speaker.shared.say(card.text) }
    }

    func next() {
        let ok = feedback?.ok ?? false
        finish(ok: ok, pct: feedback?.pct)
    }

    func finish(ok rawOk: Bool, pct: Int?) {
        guard !done else { return }
        let ok = rawOk && !selfCheck        // peeking at the answer counts as a miss, so the card returns sooner
        results[index] = ok
        let notes = store.record(card, ok: ok, pct: pct, practice: mode == .practice)
        notes.forEach { store.flash($0) }
        index += 1
        if done, passed, mode != .practice { store.grantUnlock() }
        prepare()
    }

    func retry() { prepare() }
}

struct QuizView: View {
    @StateObject var model: QuizModel
    @EnvironmentObject var store: Store
    @ObservedObject var rec = Recognizer.shared
    @Environment(\.dismiss) var dismiss
    var onAgain: (() -> Void)?

    /// The card set is built once, when the session opens, and never re-picked mid-session.
    init(model: @autoclosure @escaping () -> QuizModel, onAgain: (() -> Void)? = nil) {
        _model = StateObject(wrappedValue: model())
        self.onAgain = onAgain
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            AuroraBackground()
            VStack(spacing: 16) {
                topBar
                if model.done { resultView } else {
                    ScrollView { cardBody.padding(.bottom, 220) }.scrollIndicators(.hidden)
                }
            }
            .padding(.horizontal, 16)
            if !model.done {
                if let f = model.feedback { FeedbackSheet(feedback: f, onNext: model.next, onRetry: model.retry).transition(.move(edge: .bottom)) }
                else if model.card.kind != .listen && !model.selfCheck { footer }
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: model.feedback != nil)
        .onDisappear { rec.cancel(); Speaker.shared.stop() }
    }

    var topBar: some View {
        HStack(spacing: 12) {
            HomeButton()
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.1))
                    Capsule().fill(Color.good).frame(width: max(14, g.size.width * (model.done ? 1 : model.progress)))
                }
            }
            .frame(height: 14)
            .animation(.spring, value: model.index)
        }
        .padding(.top, 8)
    }

    // MARK: card

    @ViewBuilder var cardBody: some View {
        let c = model.card
        VStack(alignment: .leading, spacing: 16) {
            chips(c)
            if model.selfCheck { selfCheckBody(c) } else {
                switch c.kind {
                case .listen: listenBody(c)
                case .pron:
                    Eyebrow(text: L.s("Read it aloud", "Прочитайте вслух"))
                    RichKorean(text: c.text, size: 26)
                    Text(c.meaning.text(store.state.lang)).foregroundStyle(Color.muted)
                    if let u = c.unit.flatMap(store.lib.unit) {
                        TipBox(kind: .pron, title: L.s("Pronunciation", "Произношение") + " · " + u.pron.rule, bodyText: Meaning(en: u.pron.en, ru: u.pron.ru).text(store.state.lang))
                    }
                case .line:
                    if let p = c.prev {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(p.speaker).font(.caption.weight(.bold)).foregroundStyle(Color.muted)
                            RichKorean(text: p.ko, size: 17)
                            Text(p.meaning.text(store.state.lang)).font(.footnote).foregroundStyle(Color.muted)
                        }
                        .padding(14).frame(maxWidth: .infinity, alignment: .leading).glass(18)
                    }
                    Eyebrow(text: L.s("You are ", "Вы — ") + (c.speaker ?? c.unit.flatMap(store.lib.unit)?.me ?? ""))
                    RichKorean(text: c.text, size: 22)
                    Text(c.meaning.text(store.state.lang)).foregroundStyle(Color.muted)
                case .form:
                    Eyebrow(text: L.s("Make the grammar form and say it", "Образуйте форму и скажите её"))
                    HStack(spacing: 10) {
                        Text(c.example?.ko ?? "").font(.system(size: 30, weight: .bold))
                        Text("+").font(.title).foregroundStyle(Color.muted)
                        Text(c.gname ?? "").font(.system(size: 26, weight: .heavy)).foregroundStyle(Color.gram)
                    }
                    if let g = store.lib.grammarInfo(for: c) {
                        TipBox(kind: .gram, title: g.name, bodyText: Meaning(en: g.en, ru: g.ru).text(store.state.lang))
                    }
                case .word:
                    Eyebrow(text: L.s("Say the Korean word", "Скажите слово по-корейски"))
                    Text(c.meaning.text(store.state.lang)).font(.system(size: 30, weight: .bold))
                case .gram:
                    Eyebrow(text: L.s("Say the whole sentence with the missing grammar", "Скажите предложение с пропущенной грамматикой"))
                    RichKorean(text: c.text, size: 22, blankGrammar: true)
                    Text(c.meaning.text(store.state.lang)).foregroundStyle(Color.muted)
                    TipBox(kind: .gram, title: L.s("Grammar", "Грамматика") + " · " + (c.gname ?? ""),
                           bodyText: store.lib.grammarInfo(for: c).map { Meaning(en: $0.en, ru: $0.ru).text(store.state.lang) } ?? "")
                case .recall:
                    Eyebrow(text: L.s("Say it in Korean", "Скажите по-корейски"))
                    Text(c.meaning.text(store.state.lang)).font(.system(size: 28, weight: .bold))
                case .fact, .open:
                    Eyebrow(text: c.kind == .open ? L.s("Interview · answer in your own words", "Собеседование · своими словами") : L.s("Answer in Korean", "Ответьте по-корейски"))
                    HStack(alignment: .top) {
                        Text(c.question ?? "").font(.system(size: 22, weight: .bold))
                        Spacer()
                        IconButton(system: "speaker.wave.2.fill") { Speaker.shared.say(c.question ?? "") }
                    }
                    .padding(14).glass(18)
                    Text(c.qMeaning?.text(store.state.lang) ?? "").foregroundStyle(Color.muted)
                }
                if c.kind != .listen { micArea }
            }
        }
        .padding(.top, 8)
    }

    func chips(_ c: Card) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                if let u = c.unit.flatMap(store.lib.unit) { Chip(text: L.s("Unit \(u.n)", "Урок \(u.n)") + " · " + u.ko) }
                Chip(text: c.kind.label, color: c.kind == .pron ? .pron : (c.kind == .gram || c.kind == .form) ? .gram : .info)
                if c.kind == .line { Chip(text: c.scene == 0 ? L.s("말하기 dialogue", "Диалог 말하기") : L.s("듣기 conversation", "Разговор 듣기"), color: .accent) }
                if let g = c.gname { Chip(text: g, color: .gram) }
            }
        }
    }

    var micArea: some View {
        VStack(spacing: 14) {
            if model.checking {
                ProgressView().tint(.white)
                Text(L.s("Checking your answer…", "Проверяю ответ…")).foregroundStyle(Color.muted)
            } else {
                Button { toggleMic() } label: {
                    Image(systemName: rec.isRecording ? "stop.fill" : "mic.fill")
                        .font(.system(size: 38, weight: .semibold)).foregroundStyle(.white)
                        .frame(width: 104, height: 104)
                        .background(Circle().fill(rec.isRecording ? AnyShapeStyle(Color.bad) : AnyShapeStyle(brandGradient)))
                        .shadow(color: (rec.isRecording ? Color.bad : .accent).opacity(0.5), radius: 20)
                        .scaleEffect(rec.isRecording ? 1.06 : 1)
                        .animation(rec.isRecording ? .easeInOut(duration: 0.6).repeatForever() : .default, value: rec.isRecording)
                }
                Text(rec.isRecording ? (rec.transcript.isEmpty ? L.s("Listening… tap to stop", "Слушаю… нажмите, чтобы остановить") : "“\(rec.transcript)”")
                     : L.s("Tap the mic, speak, then tap again", "Нажмите на микрофон, скажите и нажмите ещё раз"))
                    .multilineTextAlignment(.center).foregroundStyle(Color.muted)
                if rec.permission == false {
                    TipBox(kind: .info, title: L.s("Microphone off", "Микрофон выключен"),
                           bodyText: L.s("Allow Microphone and Speech Recognition for Unbrick in the Settings app.", "Разрешите Unbrick доступ к микрофону и распознаванию речи в Настройках."))
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 12)
    }

    func toggleMic() {
        if rec.isRecording { rec.stop(); return }
        Speaker.shared.stop()
        Task { @MainActor in
            if rec.permission != true { guard await rec.requestPermission() else { return } }
            do { try rec.start { alts in
                if alts.isEmpty { store.flash(L.s("Didn't catch that. Try again.", "Не расслышал. Попробуйте ещё раз.")) }
                else { model.heard(alts) }
            } } catch { store.flash(error.localizedDescription) }
        }
    }

    func listenBody(_ c: Card) -> some View {
        VStack(spacing: 18) {
            Eyebrow(text: L.s("What did you hear?", "Что вы услышали?"))
            Button { Speaker.shared.say(c.text) } label: {
                Image(systemName: "speaker.wave.3.fill").font(.system(size: 36)).foregroundStyle(.white)
                    .frame(width: 104, height: 104).background(Circle().fill(brandGradient))
            }
            ForEach(model.options, id: \.self) { o in
                let right = o == c.meaning.text(store.state.lang)
                Button { model.choose(o) } label: {
                    Text(o).font(.body.weight(.semibold)).multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading).padding(16)
                        .foregroundStyle(model.picked == nil ? Color.ink : right ? .good : (model.picked == o ? .bad : .ink))
                        .background(RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.06)))
                        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(model.picked == nil ? Color.hair : right ? .good : (model.picked == o ? .bad : .hair), lineWidth: 2))
                }
                .disabled(model.picked != nil)
            }
        }
        .frame(maxWidth: .infinity)
    }

    func selfCheckBody(_ c: Card) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(c.question ?? c.meaning.text(store.state.lang)).font(.title2.weight(.bold))
            if c.kind == .open { Eyebrow(text: L.s("Sample answer", "Пример ответа")) }
            HStack { RichKorean(text: c.text, size: 22); Spacer(); PlayButtons(text: c.plain) }.padding(14).glass(18)
            Text(c.meaning.text(store.state.lang)).foregroundStyle(Color.muted)
            if let ex = c.example { TipBox(kind: .info, title: L.s("Example", "Пример"), bodyText: ex.ko + "\n" + Meaning(en: ex.en, ru: ex.ru).text(store.state.lang)) }
            TipBox(kind: .info, title: L.s("Now say it", "Теперь скажите"),
                   bodyText: L.s("Listen, then tap the mic and say it. Unbrick checks it, but a peeked card counts as missed so it comes back sooner.",
                                 "Послушайте, затем нажмите на микрофон и скажите. Unbrick проверит, но подсмотренная карточка считается ошибкой и вернётся раньше."))
            micArea
            Button(L.s("Skip this card", "Пропустить карточку")) { model.finish(ok: false, pct: nil) }
                .buttonStyle(GlassButton())
        }
        .onAppear { Speaker.shared.say(c.text) }
    }

    var footer: some View {
        HStack(spacing: 10) {
            if let q = model.card.question { Button { Speaker.shared.say(q) } label: { Image(systemName: "speaker.wave.2.fill") }.buttonStyle(GlassButton()).frame(width: 80) }
            else if !model.card.hidesAnswer { Button { Speaker.shared.say(model.card.text) } label: { Image(systemName: "speaker.wave.2.fill") }.buttonStyle(GlassButton()).frame(width: 80) }
            Button(L.s("Show answer", "Показать ответ")) { rec.cancel(); model.selfCheck = true }.buttonStyle(GlassButton())
        }
        .padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 8)
        .background(.ultraThinMaterial)
    }

    // MARK: result

    var resultView: some View {
        VStack(spacing: 18) {
            Spacer()
            Text("\(model.right)/\(model.cards.count)")
                .font(.system(size: 76, weight: .bold, design: .monospaced))
                .foregroundStyle(LinearGradient(colors: [.good, .info], startPoint: .leading, endPoint: .trailing))
            if model.mode == .practice {
                Text(L.s("Practice complete", "Тренировка завершена")).font(.title.bold())
                Text(L.s("Practice saves your scores but doesn't unlock apps.", "Тренировка сохраняет оценки, но не разблокирует приложения.")).foregroundStyle(Color.muted).multilineTextAlignment(.center)
            } else if model.passed {
                Text(L.s("Unlocked for \(store.state.intensity.minutes) minutes", "Открыто на \(store.state.intensity.minutes) мин")).font(.title.bold()).multilineTextAlignment(.center)
                Text(L.s("Your apps are open. Missed cards come back sooner.", "Приложения открыты. Ошибки вернутся раньше.")).foregroundStyle(Color.muted)
            } else {
                Text(L.s("You need \(model.need) to unlock", "Нужно \(model.need) правильных")).font(.title.bold())
                Text(L.s("New set, same goal. Missed cards come first.", "Новый набор. Ошибки — первыми.")).foregroundStyle(Color.muted)
            }
            Spacer()
            if case .role(let n) = model.mode, AI.available {
                Button { store.launch = .scene(n) } label: { Label(L.s("Keep talking with AI in this situation", "Продолжить разговор с ИИ"), systemImage: "bubble.left.and.bubble.right.fill") }
                    .buttonStyle(GlassButton())
            }
            if model.mode != .practice && !model.passed, let again = onAgain {
                Button(L.s("Try another set", "Новый набор")) { again() }.buttonStyle(PrimaryButton())
            }
            Button(model.passed || model.mode == .practice ? L.s("Back to home", "На главную") : L.s("Not now", "Не сейчас")) { store.goHome(); dismiss() }
                .buttonStyle(DuoButton(color: model.passed ? .good : .accent))
                .padding(.bottom, 12)
        }
        .padding(.horizontal, 8)
    }
}

/// Duolingo-style result sheet: green or red, with the corrected answer and tips.
struct FeedbackSheet: View {
    var feedback: Feedback
    var onNext: () -> Void
    var onRetry: () -> Void
    @State private var titleIndex = Int.random(in: 0..<3)

    var color: Color { feedback.ok ? .good : .bad }
    var title: String {
        if let t = feedback.title { return t }
        if feedback.ok { return [L.s("잘했어요! Great job!", "잘했어요! Отлично!"), L.s("완벽해요! Perfect!", "완벽해요! Идеально!"), L.s("좋아요! Nice!", "좋아요! Хорошо!")][titleIndex] }
        return L.s("Not quite", "Не совсем")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: feedback.ok ? "checkmark.circle.fill" : "xmark.circle.fill")
                Text(title)
            }
            .font(.title2.weight(.heavy)).foregroundStyle(color)
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    if let t = feedback.diffTarget, let h = feedback.heard { SyllableDiff(target: t, said: h) }
                    if let h = feedback.heard {
                        Text(L.s("Heard", "Услышано") + ": “\(h)”" + (feedback.pct.map { " · \($0)%" } ?? "")).font(.footnote).foregroundStyle(Color.muted)
                    }
                    if let n = feedback.note { Text(n).font(.subheadline) }
                    ForEach(feedback.mistakes, id: \.self) { m in
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text(m.wrong).strikethrough(color: .bad).foregroundStyle(Color.bad)
                            Image(systemName: "arrow.right").font(.caption).foregroundStyle(Color.muted)
                            Text(m.right).bold().foregroundStyle(Color.good)
                        }
                        Text(m.why).font(.caption).foregroundStyle(Color.muted)
                    }
                    if let a = feedback.answer {
                        HStack { RichKorean(text: a, size: 20); Spacer(); PlayButtons(text: Markup.plain(a)) }.padding(12).glass(16)
                    }
                    if let m = feedback.meaning { Text(m).font(.subheadline).foregroundStyle(Color.muted) }
                    ForEach(Array(feedback.tips.enumerated()), id: \.offset) { _, t in TipBox(kind: t.0, title: t.1, bodyText: t.2) }
                    if feedback.voice && Recognizer.shared.lastClip != nil {
                        Button { Recognizer.shared.playLastClip() } label: { Label(L.s("Your voice", "Ваш голос"), systemImage: "waveform") }
                            .buttonStyle(GlassButton()).frame(maxWidth: 200)
                    }
                }
            }
            .frame(maxHeight: 330)
            HStack(spacing: 10) {
                if !feedback.ok { Button(L.s("Try again", "Ещё раз"), action: onRetry).buttonStyle(GlassButton()) }
                Button(L.s("Continue", "Продолжить"), action: onNext).buttonStyle(DuoButton(color: color))
            }
        }
        .padding(18)
        .padding(.bottom, 4)
        .frame(maxWidth: .infinity)
        .background(
            UnevenRoundedRectangle(topLeadingRadius: 24, topTrailingRadius: 24)
                .fill(Color(hex: "11141C"))
                .overlay(UnevenRoundedRectangle(topLeadingRadius: 24, topTrailingRadius: 24).fill(color.opacity(0.14)))
                .ignoresSafeArea(edges: .bottom)
        )
    }
}
