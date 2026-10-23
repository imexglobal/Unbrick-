import Foundation
import Security

/// The Screen Time passcode Unbrick holds for the learner (they set it in iOS Settings without memorizing it).
enum ScreenTimeCode {
    private static let service = "com.imexglobalintl.unbrick.screentime"

    static var value: String? {
        let q: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
                                kSecReturnData as String: true, kSecMatchLimit as String: kSecMatchLimitOne]
        var out: AnyObject?
        guard SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess, let d = out as? Data else { return nil }
        return String(data: d, encoding: .utf8)
    }

    static func set(_ code: String?) {
        let base: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service]
        SecItemDelete(base as CFDictionary)
        guard let code else { return }
        var add = base
        add[kSecValueData as String] = Data(code.utf8)
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(add as CFDictionary, nil)
    }

    /// 4 digits with no repeats or straight runs, so it can't be guessed.
    static func generate() -> String {
        while true {
            let d = (0..<4).map { _ in Int.random(in: 0...9) }
            let steps = zip(d, d.dropFirst()).map { $1 - $0 }
            if Set(d).count >= 3 && !(steps.allSatisfy { $0 == 1 } || steps.allSatisfy { $0 == -1 }) { return d.map(String.init).joined() }
        }
    }
}

/// The learner's own Anthropic API key, kept in the iOS keychain.
enum APIKey {
    private static let service = "com.imexglobalintl.unbrick.anthropic"

    static var value: String? {
        let q: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
                                kSecReturnData as String: true, kSecMatchLimit as String: kSecMatchLimitOne]
        var out: AnyObject?
        guard SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess, let d = out as? Data else { return nil }
        let s = String(data: d, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (s?.isEmpty ?? true) ? nil : s
    }

    static func set(_ key: String?) {
        let base: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service]
        SecItemDelete(base as CFDictionary)
        guard let key, !key.isEmpty else { return }
        var add = base
        add[kSecValueData as String] = Data(key.utf8)
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(add as CFDictionary, nil)
    }

    static var isSet: Bool { value != nil }
}

enum ClaudeError: LocalizedError {
    case noKey, badKey, rateLimited, refused, server(Int, String), badReply
    var errorDescription: String? {
        switch self {
        case .noKey: return L.s("Add your Anthropic API key in Settings to use AI checking and the tutor.", "Добавьте ключ Anthropic API в настройках, чтобы пользоваться ИИ.")
        case .badKey: return L.s("Your API key was rejected. Check it in Settings.", "Ключ API отклонён. Проверьте его в настройках.")
        case .rateLimited: return L.s("Too many requests. Wait a minute, then try again.", "Слишком много запросов. Подождите минуту.")
        case .refused: return L.s("Claude declined this one. Try a different answer.", "Claude отказался отвечать. Попробуйте другой ответ.")
        case .server(let c, let m): return L.s("The AI service had a problem (\(c)). \(m)", "Ошибка сервиса ИИ (\(c)). \(m)")
        case .badReply: return L.s("The AI reply couldn't be read. Try again.", "Не удалось прочитать ответ ИИ. Попробуйте ещё раз.")
        }
    }
}

/// Minimal Messages API client (raw HTTPS; there is no official Swift SDK).
enum Claude {
    static let model = "claude-opus-5-5"

    /// One request that must come back as JSON matching `schema` (structured outputs).
    static func json(system: String, messages: [[String: String]], schema: [String: Any], effort: String = "low") async throws -> [String: Any] {
        guard let key = APIKey.value else { throw ClaudeError.noKey }
        var req = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        req.httpMethod = "POST"
        req.timeoutInterval = 120
        req.setValue("application/json", forHTTPHeaderField: "content-type")
        req.setValue(key, forHTTPHeaderField: "x-api-key")
        req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        // Server-side fallback: if a safety classifier declines, the API retries on Anthropic's recommended model.
        req.setValue("server-side-fallback-2026-07-01", forHTTPHeaderField: "anthropic-beta")
        let body: [String: Any] = [
            "model": model,
            "max_tokens": 16000,
            "fallbacks": "default",
            "system": system,
            "messages": messages,
            "output_config": ["effort": effort, "format": ["type": "json_schema", "schema": schema]]
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, resp) = try await URLSession.shared.data(for: req)
        let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
        let obj = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
        switch code {
        case 200: break
        case 401, 403: throw ClaudeError.badKey
        case 429: throw ClaudeError.rateLimited
        default:
            let msg = ((obj["error"] as? [String: Any])?["message"] as? String) ?? ""
            throw ClaudeError.server(code, msg)
        }
        if (obj["stop_reason"] as? String) == "refusal" { throw ClaudeError.refused }
        let text = (obj["content"] as? [[String: Any]] ?? [])
            .filter { ($0["type"] as? String) == "text" }
            .compactMap { $0["text"] as? String }
            .joined()
        guard let d = text.data(using: .utf8), let parsed = try? JSONSerialization.jsonObject(with: d) as? [String: Any] else { throw ClaudeError.badReply }
        return parsed
    }

    // MARK: schemas (strict: every property required, no extras)

    static func object(_ props: [String: Any]) -> [String: Any] {
        ["type": "object", "properties": props, "required": Array(props.keys), "additionalProperties": false]
    }
    static let str: [String: Any] = ["type": "string"]
    static let mistakes: [String: Any] = ["type": "array", "items": object(["wrong": str, "right": str, "why": str])]
    static let suggestion: [String: Any] = object(["ko": str, "m": str])

    static let judgeSchema = object([
        "correct": ["type": "boolean"], "feedback": str, "fix": str, "mistakes": mistakes, "grammar": str
    ])
    static let tutorSchema = object([
        "verdict": ["type": "string", "enum": ["correct", "incorrect", "none"]],
        "feedback": str, "mistakes": mistakes, "fix": str, "grammar": str, "question": str, "gloss": str,
        "suggestions": object(["casual": suggestion, "polite": suggestion, "formal": suggestion, "note": str])
    ])
    static let cardsSchema = object(["cards": ["type": "array", "items": object(["t": str, "m": str])]])
}

struct Mistake: Hashable { var wrong: String; var right: String; var why: String }

extension Dictionary where Key == String, Value == Any {
    func s(_ k: String) -> String { (self[k] as? String) ?? "" }
    var mistakes: [Mistake] {
        (self["mistakes"] as? [[String: Any]] ?? []).map { Mistake(wrong: $0.s("wrong"), right: $0.s("right"), why: $0.s("why")) }
    }
}
