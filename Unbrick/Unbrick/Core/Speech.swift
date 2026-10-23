import AVFoundation
import Speech

/// Korean text-to-speech. Prefers Apple's downloadable Premium / Enhanced voices (e.g. Yuna Premium).
final class Speaker: NSObject, ObservableObject {
    static let shared = Speaker()
    private let synth = AVSpeechSynthesizer()

    var voice: AVSpeechSynthesisVoice? {
        let ko = AVSpeechSynthesisVoice.speechVoices().filter { $0.language.hasPrefix("ko") }
        return ko.max { a, b in a.quality.rawValue < b.quality.rawValue } ?? AVSpeechSynthesisVoice(language: "ko-KR")
    }

    var voiceDescription: String {
        guard let v = voice else { return L.s("No Korean voice installed", "Корейский голос не установлен") }
        switch v.quality {
        case .premium: return "\(v.name) · Premium"
        case .enhanced: return "\(v.name) · Enhanced"
        default: return "\(v.name) · " + L.s("Compact (download Premium for natural speech)", "Компактный (скачайте улучшенный)")
        }
    }

    func say(_ text: String, slow: Bool = false) {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try? session.setActive(true)
        synth.stopSpeaking(at: .immediate)
        let u = AVSpeechUtterance(string: Markup.plain(text))
        u.voice = voice
        u.rate = slow ? 0.32 : 0.47
        u.preUtteranceDelay = 0.05
        synth.speak(u)
    }

    func stop() { synth.stopSpeaking(at: .immediate) }
}

enum RecognizerError: LocalizedError {
    case noInput
    var errorDescription: String? {
        L.s("The microphone isn't ready. Try again.", "Микрофон не готов. Попробуйте ещё раз.")
    }
}

/// Live Korean speech recognition that also records the learner's voice for playback.
final class Recognizer: ObservableObject {
    static let shared = Recognizer()

    @Published var transcript = ""
    @Published var isRecording = false
    @Published var permission: Bool?

    private(set) var alternatives: [String] = []
    private(set) var lastClip: URL?
    private let engine = AVAudioEngine()
    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "ko-KR"))
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var file: AVAudioFile?
    private var onFinish: (([String]) -> Void)?
    private var finished = false
    private var tapInstalled = false
    /// Bumped on every start/cancel so a late result from the previous take can't finish the next one.
    private var generation = 0
    private var player: AVAudioPlayer?

    var available: Bool { recognizer?.isAvailable ?? false }

    func requestPermission() async -> Bool {
        let speech = await withCheckedContinuation { c in SFSpeechRecognizer.requestAuthorization { c.resume(returning: $0 == .authorized) } }
        let mic = await AVAudioApplication.requestRecordPermission()
        await MainActor.run { permission = speech && mic }
        return speech && mic
    }

    func start(onFinish callback: @escaping ([String]) -> Void) throws {
        generation += 1
        let gen = generation
        stopEngine()
        onFinish = callback
        finished = false
        transcript = ""
        alternatives = []
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker])
        try session.setActive(true, options: .notifyOthersOnDeactivation)

        let req = SFSpeechAudioBufferRecognitionRequest()
        req.shouldReportPartialResults = true
        req.taskHint = .dictation
        if recognizer?.supportsOnDeviceRecognition == true {
            req.requiresOnDeviceRecognition = true
        }
        request = req

        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else {
            onFinish = nil
            throw RecognizerError.noInput
        }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("clip-\(UUID().uuidString).caf")
        file = try? AVAudioFile(forWriting: url, settings: format.settings)
        lastClip = url
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            guard let self, self.generation == gen else { return }
            self.request?.append(buffer)
            try? self.file?.write(from: buffer)
        }
        tapInstalled = true
        engine.prepare()
        do {
            try engine.start()
        } catch {
            onFinish = nil
            stopEngine()
            throw error
        }
        isRecording = true

        task = recognizer?.recognitionTask(with: req) { [weak self] result, error in
            DispatchQueue.main.async {
                guard let self, self.generation == gen else { return }
                if let r = result {
                    self.transcript = r.bestTranscription.formattedString
                    self.alternatives = [r.bestTranscription.formattedString] + r.transcriptions.map(\.formattedString)
                    if r.isFinal { self.finish() }
                }
                if error != nil { self.finish() }
            }
        }
    }

    /// Stop listening; the final result arrives shortly after, or the current one is used.
    func stop() {
        guard isRecording else { return }
        let gen = generation
        stopEngine()
        request?.endAudio()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            guard let self, self.generation == gen else { return }
            self.finish()
        }
    }

    func cancel() {
        generation += 1
        finished = true
        onFinish = nil
        task?.cancel()
        task = nil
        stopEngine()
    }

    /// `removeTap` crashes if no tap is installed, so the flag is the guard.
    private func stopEngine() {
        if engine.isRunning { engine.stop() }
        if tapInstalled {
            engine.inputNode.removeTap(onBus: 0)
            tapInstalled = false
        }
        file = nil
        isRecording = false
    }

    private func finish() {
        guard !finished else { return }
        finished = true
        stopEngine()
        task?.cancel()
        task = nil
        var seen = Set<String>()
        let alts = alternatives.filter { !$0.isEmpty && seen.insert($0).inserted }
        let cb = onFinish
        onFinish = nil
        cb?(alts)
    }

    func playLastClip() {
        guard let url = lastClip else { return }
        try? AVAudioSession.sharedInstance().setCategory(.playback)
        player = try? AVAudioPlayer(contentsOf: url)
        player?.play()
    }
}
