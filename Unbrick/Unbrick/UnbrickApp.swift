import SwiftUI
import AppIntents

@main
struct UnbrickApp: App {
    @StateObject private var store = Store.shared

    init() {
        LegacyKeychainCleanup.removeEmbeddedAnthropicKey()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .preferredColorScheme(.dark)
                .tint(.accent)
                .onOpenURL { store.handle($0) }
        }
    }
}

/// The blocked-app screen, plus the session it launches.
struct ShieldFlow: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) var dismiss
    let app: String
    @State private var next: Sheet?
    @State private var key = UUID()

    var body: some View {
        ShieldView(app: app,
                   onCards: { key = UUID(); next = .quiz(.cards) },
                   onRole: { key = UUID(); next = .quiz(.role(store.state.unit)) },
                   onTutor: { next = .tutor },
                   onClose: { dismiss() })
        .fullScreenCover(item: $next, onDismiss: { if store.unlocked { dismiss() } }) { s in
            switch s {
            case .quiz(let mode):
                let cards: [Card] = { if case .role(let n) = mode { return store.roleplayCards(unit: n) } else { return store.pickCards() } }()
                QuizView(model: QuizModel(mode: mode, cards: cards), onAgain: { key = UUID() }).id(key)
            default: TutorView()
            }
        }
    }
}

// MARK: - App Intents for the Shortcuts-based blocker

struct IsUnbrickLockedIntent: AppIntent {
    static var title: LocalizedStringResource = "Is Unbrick Locked"
    static var description = IntentDescription("True while your apps are bricked; false during an unlock window.")

    func perform() async throws -> some IntentResult & ReturnsValue<Bool> {
        .result(value: Store.lockedNow())
    }
}

struct ShowShieldIntent: AppIntent {
    static var title: LocalizedStringResource = "Show Unbrick Shield"
    static var description = IntentDescription("Opens Unbrick on the bricked screen so you can speak Korean to unlock.")
    static var openAppWhenRun = true

    @Parameter(title: "App name", default: "This app")
    var app: String

    @MainActor
    func perform() async throws -> some IntentResult {
        Store.shared.showShield(app)
        return .result()
    }
}

struct UnbrickShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: IsUnbrickLockedIntent(), phrases: ["Is \(.applicationName) locked"], shortTitle: "Lock status", systemImageName: "lock")
        AppShortcut(intent: ShowShieldIntent(), phrases: ["Open \(.applicationName) shield"], shortTitle: "Shield", systemImageName: "lock.shield")
    }
}

struct RootView: View {
    @EnvironmentObject var store: Store

    var body: some View {
        ZStack(alignment: .top) {
            if let err = store.lib.loadError {
                Text(L.s("Lessons didn't load. \(err)", "Уроки не загрузились. \(err)"))
                    .font(.footnote).foregroundStyle(Color.bad)
                    .padding(12).frame(maxWidth: .infinity, alignment: .leading).glass(16)
                    .padding(.horizontal, 16).padding(.top, 8)
                    .zIndex(9)
            }
            if store.state.setupDone {
                TabView(selection: $store.tab) {
                    HomeView().tag(Tab.home)
                        .tabItem { Label(L.s("Home", "Главная"), systemImage: "house.fill") }
                    LearnView().tag(Tab.learn)
                        .tabItem { Label(L.s("Learn", "Учёба"), systemImage: "book.fill") }
                    CalendarView().tag(Tab.calendar)
                        .tabItem { Label(L.s("Calendar", "Календарь"), systemImage: "calendar") }
                    ProfileView().tag(Tab.profile)
                        .tabItem { Label(L.s("Profile", "Профиль"), systemImage: "person.crop.circle.fill") }
                }
            } else {
                SetupView(isEdit: false)
            }
            if let t = store.toast {
                Text(t).font(.subheadline.weight(.semibold)).multilineTextAlignment(.center)
                    .padding(.horizontal, 16).padding(.vertical, 12).glass(16)
                    .padding(.horizontal, 16).padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(10)
            }
        }
        .animation(.spring, value: store.toast)
        .fullScreenCover(item: $store.launch) { s in SheetContent(sheet: s) }
        .fullScreenCover(item: Binding(get: { store.shieldApp.map { ShieldApp(name: $0) } }, set: { store.shieldApp = $0?.name })) { s in
            ShieldFlow(app: s.name)
        }
    }

    struct ShieldApp: Identifiable { var id: String { name }; let name: String }
}

/// What a full-screen sheet shows. Sessions are built once when the sheet opens.
struct SheetContent: View {
    @EnvironmentObject var store: Store
    let sheet: Sheet
    @State private var round = UUID()

    var body: some View {
        switch sheet {
        case .quiz(let mode):
            QuizView(model: QuizModel(mode: mode, cards: cards(for: mode)), onAgain: { round = UUID() }).id(round)
        case .practice(_, let cards):
            QuizView(model: QuizModel(mode: .practice, cards: cards))
        case .tutor: TutorView()
        case .scene(let n): TutorView(model: TutorModel(sceneUnit: n))
        case .review: ReviewView()
        case .setup: SetupView(isEdit: true)
        case .blocking: BlockingGuideView()
        }
    }

    func cards(for mode: QuizMode) -> [Card] {
        if case .role(let n) = mode { return store.roleplayCards(unit: n) }
        if mode == .review { return store.reviewCards() }
        return store.pickCards()
    }
}
