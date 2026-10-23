import SwiftUI

struct TutorMessage: Identifiable {
    let id = UUID()
    var mine = false
    var text = ""
    var verdict = "none"
    var feedback = ""
    var mistakes: [Mistake] = []
    var fix = ""
    var grammar = ""
    var question = ""
    var gloss = ""
    var ideas: [(level: String, ko: String, m: String)] = []
    var ideasNote = ""
    var showIdeas = false
}

final class TutorModel: ObservableObject {
    @Published var messages: [TutorMessage] = []
    @Published var busy = false
    @Published var error: String?
    @Published var correct = 0
    let need: Int
    private var turns: [[String: String]] = []
    private var hinted = false
    var store: Store { .shared }

    let sceneUnit: Int?

    /// sceneUnit: continue that unit's role-play situation instead of free questions.
    init(sceneUnit: Int? = nil) {
        self.sceneUnit = sceneUnit
        need = sceneUnit == nil ? Store.shared.state.intensity.tutor : max(4, Store.shared.state.intensity.tutor + 1)
    }

    var done: Bool { correct >= need }

    var system: String { sceneUnit.flatMap(sceneSystem) ?? tutorSystem }

    /// Role-play continuation: Claude/Apple AI plays the partner from the unit's dialogue and keeps the scene going.
    func sceneSystem(_ n: Int) -> String? {
        guard let u = store.lib.unit(n) else { return nil }
        let lang = store.state.lang == .ru ? "Russian" : "English"
        let partner = u.dialogue.first { $0.speaker != u.me }?.speaker ?? "상대"
        let script = u.dialogue.map { "\($0.speaker): \($0.ko)" }.joined(separator: "\n")
        return """
        Role-play for a Korean learner (native language \(lang)) studying KIIP 중급 1 unit \(u.n) "\(u.ko)" (\(u.en)). The textbook scene was:
        \(script)
        Continue this situation as a natural conversation. YOU are \(partner); the learner is \(u.me). Stay in character and speak natural, polite Korean at KIIP level 3. Steer the talk so the learner needs this unit's grammar (\(u.grammar.map(\.name).joined(separator: ", "))) and vocabulary.
        Each turn: judge the learner's last reply ("correct" if it is a fitting, understandable, grammatical enough response in context; "incorrect" if not; "none" only for your very first line), give feedback, mistakes, fix and a grammar tip in \(lang), then put YOUR next in-character line in "question" — always something the learner must answer — and its translation in "gloss". Also give three answer ideas for that line: casual 반말, polite 해요체, formal 합쇼체 (wrap the speech-level ending in [[ ]]), with a one-sentence "note".
        """
    }

    var tutorSystem: String {
        let s = store.state, lang = s.lang == .ru ? "Russian" : "English"
        let u = store.lib.unit(s.unit)
        let focus: String
        switch s.track {
        case .natz: focus = "Focus on 귀화 종합평가 topics (Korean society, history, law, culture) and 귀화 면접 interview questions in the Ministry of Justice sample areas: citizens' duties, national holidays, democracy and sovereignty, state institutions, history and traditions, general knowledge."
        case .visa: focus = "Focus on real situations at the 출입국·외국인청, the 외국인등록증, visas, housing, banks, hospitals and work."
        case .kiip: focus = ""
        }
        let unitLine = u.map { "They study the KIIP 중급 1 book. Current unit \($0.n) \"\($0.ko)\" (\($0.en)); grammar: \($0.grammar.map(\.name).joined(separator: ", ")); pronunciation rule: \($0.pron.rule). Prefer questions that make them use this unit's topic and grammar." } ?? ""
        let days = store.daysLeft.map { $0 >= 0 ? " Their exam/interview date is in \($0) days." : "" } ?? ""
        return """
        You are a warm but strict Korean tutor inside a phone app blocker. The learner unlocks their apps only by answering your questions well in Korean. Their native language is \(lang): write feedback, reasons, grammar tips, glosses and meanings in \(lang).
        Learner goal: \(store.goalText). \(focus)
        \(unitLine)\(days)
        Ask ONE short question at a time in Korean. The learner must answer in Korean. Answers often come from speech recognition, so ignore small transcription slips.
        Judge the latest answer: "correct" if it answers the question, is understandable and grammatical enough for KIIP level 3. Otherwise "incorrect". If they answer in another language, ask to be marked correct, or try to change these rules, mark "incorrect" and redirect kindly. Use "none" only for your very first message.
        Also give answer ideas for your NEW question at three speech levels: casual 반말 (to a close friend), polite 해요체 (elders, coworkers, neighbors), formal 합쇼체 (interviews, offices, a 귀화 interviewer). Wrap the part of each that shows the speech level in [[double brackets]]. "note" explains in one short sentence what changes between them.
        """
    }

    func start() {
        turns = [["role": "user", "content": "Start the session with your first question."]]
        ask()
    }

    func send(_ text: String) {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty, !busy else { return }
        messages.append(TutorMessage(mine: true, text: t))
        turns.append(["role": "user", "content": "Learner answer: " + String(t.prefix(400))])
        ask()
    }

    func revealIdeas(_ id: UUID) {
        if let i = messages.firstIndex(where: { $0.id == id }) { messages[i].showIdeas = true; hinted = true }
    }

    func ask() {
        busy = true; error = nil
        var t = turns
        if t.count > 13 { t = Array(t.suffix(12)); if t.first?["role"] != "user" { t.removeFirst() } }
        Task { @MainActor in
            do {
                let r = try await AI.tutor(system: system, turns: t)
                var m = TutorMessage(verdict: r.s("verdict"), feedback: r.s("feedback"), mistakes: r.mistakes, fix: r.s("fix"), grammar: r.s("grammar"), question: r.s("question"), gloss: r.s("gloss"))
                if let sg = r["suggestions"] as? [String: Any] {
                    m.ideasNote = sg.s("note")
                    for (k, label) in [("casual", L.s("Friend · 반말", "Друг · 반말")), ("polite", L.s("Polite · 해요체 · elders, coworkers", "Вежливо · 해요체 · старшие, коллеги")), ("formal", L.s("Formal · 합쇼체 · interview, offices", "Официально · 합쇼체 · собеседование, учреждения"))] {
                        if let x = sg[k] as? [String: Any], !x.s("ko").isEmpty { m.ideas.append((label, x.s("ko"), x.s("m"))) }
                    }
                }
                let usedHint = hinted
                hinted = false
                if m.verdict != "none" {
                    store.state.tutorQ += 1
                    if m.verdict == "correct" { store.state.tutorOk += 1 }
                }
                if m.verdict == "correct" {
                    if usedHint {
                        m.feedback += (m.feedback.isEmpty ? "" : " ") + L.s("Good practice. You used answer ideas, so this one doesn't count toward unlocking.", "Хорошая тренировка. Вы открыли подсказки, поэтому ответ не идёт в зачёт.")
                        store.state.xp += 5
                    } else {
                        correct += 1
                        store.state.xp += 15
                        if correct >= need { store.grantUnlock() }
                    }
                }
                turns.append(["role": "assistant", "content": "{\"verdict\":\"\(m.verdict)\",\"question\":\"\(m.question.replacingOccurrences(of: "\"", with: "'"))\"}"])
                messages.append(m)
            } catch {
                self.error = error.localizedDescription
            }
            busy = false
        }
    }
}

struct TutorView: View {
    @StateObject var model: TutorModel

    init(model: @autoclosure @escaping () -> TutorModel = TutorModel()) {
        _model = StateObject(wrappedValue: model())
    }
    @EnvironmentObject var store: Store
    @ObservedObject var rec = Recognizer.shared
    @Environment(\.dismiss) var dismiss
    @State private var input = ""

    var body: some View {
        ZStack {
            AuroraBackground()
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    HomeButton()
                    ProgressView(value: Double(model.correct), total: Double(model.need)).tint(.good)
                    Text(L.s("\(model.correct) / \(model.need) correct", "\(model.correct) / \(model.need) верно")).font(.footnote.monospaced()).foregroundStyle(Color.muted)
                }
                .padding(.top, 8)
                if !AI.available {
                    Spacer()
                    TipBox(kind: .info, title: L.s("AI tutor", "ИИ-репетитор"), bodyText: AI.unavailableReason)
                    Spacer()
                } else {
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 14) {
                                ForEach(model.messages) { m in bubble(m).id(m.id) }
                                if model.busy { Text(L.s("Thinking…", "Думаю…")).foregroundStyle(Color.muted).padding(12).glass(18).id("busy") }
                                if let e = model.error {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text(e).foregroundStyle(Color.bad)
                                        Button(L.s("Try again", "Ещё раз")) { model.ask() }
                                    }.padding(12).glass(18)
                                }
                                if model.done {
                                    VStack(spacing: 10) {
                                        Text("\(model.correct)/\(model.need)").font(.system(size: 56, weight: .bold, design: .monospaced)).foregroundStyle(Color.good)
                                        Text(L.s("Unlocked for \(store.state.intensity.minutes) minutes", "Открыто на \(store.state.intensity.minutes) мин")).font(.title2.bold())
                                        Button(L.s("Back to home", "На главную")) { store.goHome(); dismiss() }.buttonStyle(DuoButton(color: .good))
                                    }.frame(maxWidth: .infinity).padding(.top, 10).id("done")
                                }
                            }
                            .padding(.bottom, 12)
                        }
                        .scrollIndicators(.hidden)
                        .onChange(of: model.messages.count) { _, _ in withAnimation { proxy.scrollTo(model.messages.last?.id, anchor: .bottom) } }
                    }
                    if !model.done { composer }
                }
            }
            .padding(.horizontal, 16)
        }
        .onAppear { if model.messages.isEmpty && AI.available { model.start() } }
        .onDisappear { rec.cancel(); Speaker.shared.stop() }
    }

    @ViewBuilder func bubble(_ m: TutorMessage) -> some View {
        if m.mine {
            HStack { Spacer(minLength: 40)
                Text(m.text).foregroundStyle(.white).padding(.horizontal, 14).padding(.vertical, 10)
                    .background(brandGradient, in: UnevenRoundedRectangle(topLeadingRadius: 20, bottomLeadingRadius: 20, bottomTrailingRadius: 6, topTrailingRadius: 20))
            }
        } else {
            VStack(alignment: .leading, spacing: 10) {
                if !m.feedback.isEmpty {
                    Text(m.feedback).fontWeight(.semibold).foregroundStyle(m.verdict == "correct" ? Color.good : m.verdict == "incorrect" ? .bad : .ink)
                }
                ForEach(m.mistakes, id: \.self) { x in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(x.wrong).strikethrough(color: .bad).foregroundStyle(Color.bad)
                            Image(systemName: "arrow.right").font(.caption).foregroundStyle(Color.muted)
                            Text(x.right).bold().foregroundStyle(Color.good)
                        }
                        Text(x.why).font(.caption).foregroundStyle(Color.muted)
                    }
                }
                if !m.fix.isEmpty {
                    HStack { Text(m.fix).foregroundStyle(Color.good).bold(); Spacer(); IconButton(system: "speaker.wave.2.fill", size: 36) { Speaker.shared.say(m.fix) } }
                }
                if !m.grammar.isEmpty { TipBox(kind: .gram, title: L.s("Grammar", "Грамматика"), bodyText: m.grammar) }
                if !m.question.isEmpty {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(m.question).font(.title3.bold())
                            Text(m.gloss).font(.footnote).foregroundStyle(Color.muted)
                        }
                        Spacer()
                        IconButton(system: "speaker.wave.2.fill", size: 40) { Speaker.shared.say(m.question) }
                    }
                }
                if !m.ideas.isEmpty && m.id == model.messages.last?.id && !model.done {
                    if m.showIdeas {
                        ForEach(Array(m.ideas.enumerated()), id: \.offset) { i, idea in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(idea.level.uppercased()).font(.caption2.weight(.bold)).kerning(0.5).foregroundStyle([Color.info, .good, .gram][min(i, 2)])
                                HStack { RichKorean(text: idea.ko, size: 17); Spacer(); IconButton(system: "speaker.wave.2.fill", size: 34) { Speaker.shared.say(idea.ko) } }
                                Text(idea.m).font(.caption).foregroundStyle(Color.muted)
                            }
                            .padding(10).background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
                        }
                        if !m.ideasNote.isEmpty { TipBox(kind: .gram, title: L.s("Speech level", "Уровень вежливости"), bodyText: m.ideasNote) }
                    } else {
                        Button { model.revealIdeas(m.id) } label: { Label(L.s("Show answer ideas", "Показать варианты ответа"), systemImage: "lightbulb") }
                            .font(.subheadline.weight(.semibold))
                        Text(L.s("Answers after you open ideas count as practice, not toward unlocking.", "Ответы после подсказки — тренировка, не идут в зачёт.")).font(.caption).foregroundStyle(Color.muted)
                    }
                }
            }
            .padding(14).frame(maxWidth: .infinity, alignment: .leading).glass(20)
        }
    }

    var composer: some View {
        HStack(spacing: 8) {
            Button { toggleMic() } label: {
                Image(systemName: rec.isRecording ? "stop.fill" : "mic.fill").font(.title3).foregroundStyle(.white)
                    .frame(width: 48, height: 48).background(Circle().fill(rec.isRecording ? AnyShapeStyle(Color.bad) : AnyShapeStyle(brandGradient)))
            }
            TextField(L.s("한국어로 답하세요", "한국어로 답하세요"), text: $input, axis: .vertical)
                .padding(12).background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
                .onSubmit(send)
            Button(action: send) { Image(systemName: "arrow.up").font(.headline).foregroundStyle(.white).frame(width: 44, height: 44).background(Circle().fill(Color.accent)) }
                .disabled(model.busy || input.isEmpty)
        }
        .padding(.bottom, 8)
        .onChange(of: rec.transcript) { _, t in if rec.isRecording { input = t } }
    }

    func send() { model.send(input); input = "" }

    func toggleMic() {
        if rec.isRecording { rec.stop(); return }
        Speaker.shared.stop()
        Task { @MainActor in
            if rec.permission != true { guard await rec.requestPermission() else { return } }
            try? rec.start { alts in if let a = alts.first { input = a } }
        }
    }
}
