import Foundation

/// Official KIIP stage names. Lesson text for each stage lives in Content.json.
enum Levels {
    static let all = [0, 1, 2, 3, 4, 5]

    static func ko(_ n: Int) -> String {
        switch n {
        case 0: return "기초"
        case 1: return "초급 1"
        case 2: return "초급 2"
        case 3: return "중급 1"
        case 4: return "중급 2"
        case 5: return "한국사회 이해"
        default: return "KIIP \(n)"
        }
    }

    static func gloss(_ n: Int, _ lang: Lang) -> String {
        let en: String
        let ru: String
        switch n {
        case 0: en = "Basic"; ru = "Базовый"
        case 1: en = "Beginner 1"; ru = "Начальный 1"
        case 2: en = "Beginner 2"; ru = "Начальный 2"
        case 3: en = "Intermediate 1"; ru = "Средний 1"
        case 4: en = "Intermediate 2"; ru = "Средний 2"
        case 5: en = "Korean society"; ru = "Корейское общество"
        default: en = "Level \(n)"; ru = "Уровень \(n)"
        }
        return lang == .ru ? ru : en
    }

    static func title(_ n: Int, _ lang: Lang) -> String { "\(n) · \(ko(n))" }

    static func line(_ n: Int, _ lang: Lang) -> String { "\(title(n, lang)) · \(gloss(n, lang))" }
}

/// Six original questions, one step harder each. The score picks a starting level.
struct PlacementQuestion: Identifiable {
    var id: Int
    var prompt: String
    var promptRu: String
    var choices: [String]
    var choicesRu: [String]
    var answer: Int
}

enum Placement {
    static let questions: [PlacementQuestion] = [
        PlacementQuestion(id: 0,
                          prompt: "What does 안녕하세요 mean?",
                          promptRu: "Что значит 안녕하세요?",
                          choices: ["Hello", "Thank you", "Goodbye", "Sorry"],
                          choicesRu: ["Здравствуйте", "Спасибо", "До свидания", "Извините"],
                          answer: 0),
        PlacementQuestion(id: 1,
                          prompt: "물이 있어요. What does this say?",
                          promptRu: "Что значит 물이 있어요?",
                          choices: ["There is water.", "I am water.", "The water is hot.", "Please drink."],
                          choicesRu: ["Есть вода.", "Я — вода.", "Вода горячая.", "Пейте, пожалуйста."],
                          answer: 0),
        PlacementQuestion(id: 2,
                          prompt: "어제 친구를 만났어요. When did this happen?",
                          promptRu: "Когда это было: 어제 친구를 만났어요?",
                          choices: ["Tomorrow", "Every day", "Yesterday", "Right now"],
                          choicesRu: ["Завтра", "Каждый день", "Вчера", "Сейчас"],
                          answer: 2),
        PlacementQuestion(id: 3,
                          prompt: "비가 와서 집에 있어요. Why are they home?",
                          promptRu: "Почему человек дома: 비가 와서 집에 있어요?",
                          choices: ["Because it is raining", "Even though it is raining", "Before it rains", "If it rains tomorrow"],
                          choicesRu: ["Потому что идёт дождь", "Хотя идёт дождь", "До дождя", "Если завтра пойдёт дождь"],
                          answer: 0),
        PlacementQuestion(id: 4,
                          prompt: "일회용품을 줄여야 환경이 나아집니다. What should people do?",
                          promptRu: "Что нужно делать: 일회용품을 줄여야 환경이 나아집니다?",
                          choices: ["Use more disposable items", "Use fewer disposable items", "Move to another city", "Ignore the news"],
                          choicesRu: ["Больше одноразовых вещей", "Меньше одноразовых вещей", "Переехать в другой город", "Не читать новости"],
                          answer: 1),
        PlacementQuestion(id: 5,
                          prompt: "국회의원은 국민의 선거로 뽑힙니다. How are they chosen?",
                          promptRu: "Как выбирают: 국회의원은 국민의 선거로 뽑힙니다?",
                          choices: ["The president appoints each one", "Voters elect them", "They inherit the seat", "A school exam decides"],
                          choicesRu: ["Президент назначает каждого", "Их выбирают избиратели", "Место передаётся по наследству", "Решает школьный экзамен"],
                          answer: 1)
    ]

    /// 0–1 correct starts at 기초. A perfect score starts at 한국사회 이해.
    static func level(forCorrect correct: Int) -> Int {
        switch correct {
        case 0, 1: return 0
        case 2: return 1
        case 3: return 2
        case 4: return 3
        case 5: return 4
        default: return 5
        }
    }
}
