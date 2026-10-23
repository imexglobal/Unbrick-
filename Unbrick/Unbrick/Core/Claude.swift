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

/// Stable id for the per-device daily cap. A Keychain UUID, not the vendor id.
enum DeviceId {
    private static let service = "com.imexglobalintl.unbrick.device"
    private static var cached: String?

    static var value: String {
        if let cached, valid(cached) { return cached }
        if let existing = read(), valid(existing) {
            cached = existing
            return existing
        }
        let fresh = UUID().uuidString
        write(fresh)
        cached = fresh
        return fresh
    }

    private static func valid(_ value: String) -> Bool {
        let allowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_-")
        return (8...80).contains(value.count) && value.unicodeScalars.allSatisfy { allowed.contains($0) }
    }

    private static func read() -> String? {
        let q: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
                                kSecReturnData as String: true, kSecMatchLimit as String: kSecMatchLimitOne]
        var out: AnyObject?
        guard SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess, let data = out as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private static func write(_ value: String) {
        let base: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service]
        SecItemDelete(base as CFDictionary)
        var add = base
        add[kSecValueData as String] = Data(value.utf8)
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(add as CFDictionary, nil)
    }
}

/// Where this build sends tutor and grading requests. The Anthropic key lives only on that server.
enum ProxyConfig {
    static var baseURL: URL? {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: "UNBRICK_API_BASE") as? String else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed), let scheme = url.scheme?.lowercased(), let host = url.host, !host.isEmpty else { return nil }
        if scheme == "https" { return url }
        #if DEBUG
        if scheme == "http", host == "localhost" || host == "127.0.0.1" { return url }
        #endif
        return nil
    }

    /// Shared with the proxy. It is not the Anthropic key; it only raises the cost of casual abuse.
    static var appToken: String? {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: "UNBRICK_APP_TOKEN") as? String else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    static var privacyURL: URL? { httpsURL("UNBRICK_PRIVACY_URL") }

    static var supportURL: URL? { httpsURL("UNBRICK_SUPPORT_URL") }

    private static func httpsURL(_ key: String) -> URL? {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: key) as? String else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed), url.scheme?.lowercased() == "https" else { return nil }
        return url
    }

    static var isConfigured: Bool { baseURL != nil && appToken != nil }
}

/// Older builds let a learner paste an Anthropic key into the Keychain and called the API from the phone.
enum LegacyKeychainCleanup {
    static func removeEmbeddedAnthropicKey() {
        let base: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.imexglobalintl.unbrick.anthropic"
        ]
        SecItemDelete(base as CFDictionary)
    }
}

enum ClaudeError: LocalizedError {
    case notConfigured, rateLimited, resting, refused, offline, server(Int, String), badReply
    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return L.s("Claude isn't available on this build yet. Turn on Apple Intelligence for on-device checking, or ship the app with the Unbrick server URL.",
                       "Claude в этой сборке ещё не подключён. Включите Apple Intelligence для проверки на устройстве или укажите адрес сервера Unbrick.")
        case .rateLimited: return L.s("Too many requests. Wait a minute, then try again.", "Слишком много запросов. Подождите минуту.")
        case .resting: return L.s("AI tutor is resting, try again tomorrow", "ИИ-репетитор отдыхает. Попробуйте завтра.")
        case .refused: return L.s("Claude declined this one. Try a different answer.", "Claude отказался отвечать. Попробуйте другой ответ.")
        case .offline: return L.s("You appear to be offline. Try again when you have a connection.", "Нет сети. Попробуйте, когда появится соединение.")
        case .server(let c, let m): return L.s("The AI service had a problem (\(c)). \(m)", "Ошибка сервиса ИИ (\(c)). \(m)")
        case .badReply: return L.s("The AI reply couldn't be read. Try again.", "Не удалось прочитать ответ ИИ. Попробуйте ещё раз.")
        }
    }
}

/// Talks to the Unbrick proxy (`backend/`). The proxy owns the model, the JSON schema, and the Anthropic key.
enum Claude {
    static func json(system: String, messages: [[String: String]], task: String, effort: String = "low") async throws -> [String: Any] {
        guard let base = ProxyConfig.baseURL, let token = ProxyConfig.appToken else { throw ClaudeError.notConfigured }
        var req = URLRequest(url: base.appending(path: "v1/task"))
        req.httpMethod = "POST"
        req.timeoutInterval = 90
        req.setValue("application/json", forHTTPHeaderField: "content-type")
        req.setValue(token, forHTTPHeaderField: "X-Unbrick-Token")
        req.setValue(DeviceId.value, forHTTPHeaderField: "X-Unbrick-Device")
        let body: [String: Any] = ["task": task, "system": system, "messages": messages, "effort": effort]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let data: Data
        let resp: URLResponse
        do {
            (data, resp) = try await URLSession.shared.data(for: req)
        } catch let error as URLError {
            switch error.code {
            case .notConnectedToInternet, .networkConnectionLost, .timedOut, .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed:
                throw ClaudeError.offline
            default:
                throw ClaudeError.server(0, error.localizedDescription)
            }
        }
        let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
        let obj = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
        switch code {
        case 200: return obj
        case 401, 403: throw ClaudeError.notConfigured
        case 429:
            let code = (obj["error"] as? [String: Any])?["code"] as? String
            throw code == "resting" ? ClaudeError.resting : ClaudeError.rateLimited
        case 422: throw ClaudeError.refused
        default:
            let msg = ((obj["error"] as? [String: Any])?["message"] as? String) ?? ""
            throw ClaudeError.server(code, msg)
        }
    }
}

struct Mistake: Hashable { var wrong: String; var right: String; var why: String }

extension Dictionary where Key == String, Value == Any {
    func s(_ k: String) -> String { (self[k] as? String) ?? "" }
    var mistakes: [Mistake] {
        (self["mistakes"] as? [[String: Any]] ?? []).map { Mistake(wrong: $0.s("wrong"), right: $0.s("right"), why: $0.s("why")) }
    }
}
