import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// One place for AI: Claude when the learner has added an API key, otherwise Apple's on-device model
/// (Apple Intelligence, free and offline). Both return the same dictionary shape the UI already reads.
enum AI {
    enum Engine { case claude, onDevice, none }

    static var engine: Engine {
        if APIKey.isSet { return .claude }
        if onDeviceReady { return .onDevice }
        return .none
    }
    static var available: Bool { engine != .none }

    static var onDeviceReady: Bool {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) { return SystemLanguageModel.default.availability == .available }
        #endif
        return false
    }

    static var engineName: String {
        switch engine {
        case .claude: return "Claude"
        case .onDevice: return L.s("Apple on-device AI", "ИИ Apple на устройстве")
        case .none: return L.s("Off", "Выключен")
        }
    }

    static var unavailableReason: String {
        L.s("AI checking needs Apple Intelligence (Settings › Apple Intelligence & Siri › turn on) or an Anthropic API key in Profile.",
            "Для ИИ-проверки включите Apple Intelligence (Настройки › Apple Intelligence и Siri) или добавьте ключ Anthropic в Профиле.")
    }

    // MARK: grading one spoken answer

    static func judge(system: String, prompt: String) async throws -> [String: Any] {
        switch engine {
        case .claude:
            return try await Claude.json(system: system, messages: [["role": "user", "content": prompt]], schema: Claude.judgeSchema)
        case .onDevice:
            #if canImport(FoundationModels)
            if #available(iOS 26.0, *) {
                let session = LanguageModelSession(instructions: system)
                let r = try await session.respond(to: prompt, generating: ODJudgment.self).content
                return ["correct": r.correct, "feedback": r.feedback, "fix": r.fix, "grammar": r.grammar,
                        "mistakes": r.mistakes.map { ["wrong": $0.wrong, "right": $0.right, "why": $0.why] }]
            }
            #endif
            throw ClaudeError.noKey
        case .none:
            throw ClaudeError.noKey
        }
    }

    // MARK: tutor turn

    static func tutor(system: String, turns: [[String: String]]) async throws -> [String: Any] {
        switch engine {
        case .claude:
            return try await Claude.json(system: system, messages: turns, schema: Claude.tutorSchema)
        case .onDevice:
            #if canImport(FoundationModels)
            if #available(iOS 26.0, *) {
                let session = LanguageModelSession(instructions: system)
                let transcript = turns.map { ($0["role"] == "assistant" ? "Tutor: " : "") + ($0["content"] ?? "") }.joined(separator: "\n")
                let r = try await session.respond(to: transcript + "\n\nReply as the tutor now.", generating: ODTutor.self).content
                func idea(_ i: ODIdea) -> [String: Any] { ["ko": i.ko, "m": i.m] }
                return ["verdict": r.verdict, "feedback": r.feedback, "fix": r.fix, "grammar": r.grammar, "question": r.question, "gloss": r.gloss,
                        "mistakes": r.mistakes.map { ["wrong": $0.wrong, "right": $0.right, "why": $0.why] },
                        "suggestions": ["casual": idea(r.casual), "polite": idea(r.polite), "formal": idea(r.formal), "note": r.note]]
            }
            #endif
            throw ClaudeError.noKey
        case .none:
            throw ClaudeError.noKey
        }
    }

    // MARK: card generation

    static func cards(system: String, prompt: String) async throws -> [[String: Any]] {
        switch engine {
        case .claude:
            let r = try await Claude.json(system: system, messages: [["role": "user", "content": prompt]], schema: Claude.cardsSchema, effort: "medium")
            return r["cards"] as? [[String: Any]] ?? []
        case .onDevice:
            #if canImport(FoundationModels)
            if #available(iOS 26.0, *) {
                let session = LanguageModelSession(instructions: system)
                let r = try await session.respond(to: prompt, generating: ODCards.self).content
                return r.cards.map { ["t": $0.t, "m": $0.m] }
            }
            #endif
            throw ClaudeError.noKey
        case .none:
            throw ClaudeError.noKey
        }
    }
}

#if canImport(FoundationModels)
@available(iOS 26.0, *)
@Generable struct ODMistake {
    @Guide(description: "The exact part the learner said that is wrong, in Korean")
    var wrong: String
    @Guide(description: "The correct Korean for that part")
    var right: String
    @Guide(description: "A very short reason, in the learner's native language")
    var why: String
}

@available(iOS 26.0, *)
@Generable struct ODJudgment {
    @Guide(description: "true if the answer is acceptable")
    var correct: Bool
    @Guide(description: "1-2 short sentences of feedback in the learner's native language")
    var feedback: String
    @Guide(description: "A natural corrected Korean sentence, or empty")
    var fix: String
    @Guide(description: "Specific mistakes, empty if none", .maximumCount(4))
    var mistakes: [ODMistake]
    @Guide(description: "One useful grammar note in the learner's native language, or empty")
    var grammar: String
}

@available(iOS 26.0, *)
@Generable struct ODIdea {
    @Guide(description: "A Korean answer; wrap the speech-level ending in [[double brackets]]")
    var ko: String
    @Guide(description: "Its meaning in the learner's native language")
    var m: String
}

@available(iOS 26.0, *)
@Generable struct ODTutor {
    @Guide(description: "Judgment of the learner's latest answer", .anyOf(["correct", "incorrect", "none"]))
    var verdict: String
    var feedback: String
    @Guide(.maximumCount(4))
    var mistakes: [ODMistake]
    var fix: String
    var grammar: String
    @Guide(description: "The next short question, in Korean")
    var question: String
    @Guide(description: "Translation of the question in the learner's native language")
    var gloss: String
    @Guide(description: "Answer to the new question in 반말, for a close friend")
    var casual: ODIdea
    @Guide(description: "Same answer in 해요체, for elders and coworkers")
    var polite: ODIdea
    @Guide(description: "Same answer in 합쇼체, for interviews and offices")
    var formal: ODIdea
    @Guide(description: "One short sentence on what changes between the three speech levels")
    var note: String
}

@available(iOS 26.0, *)
@Generable struct ODCard {
    @Guide(description: "A Korean sentence the learner would say")
    var t: String
    @Guide(description: "Its meaning in the learner's native language")
    var m: String
}

@available(iOS 26.0, *)
@Generable struct ODCards {
    @Guide(.count(8))
    var cards: [ODCard]
}
#endif
