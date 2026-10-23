import SwiftUI
import UIKit

/// Real blocking with iOS Screen Time: Unbrick holds the Screen Time passcode and reveals it only during an earned unlock.
struct BlockingGuideView: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) var dismiss
    @State private var code = ScreenTimeCode.value
    @State private var confirmReset = false

    var body: some View {
        ZStack {
            AuroraBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Button { dismiss() } label: { Image(systemName: "xmark").font(.title3.weight(.semibold)).foregroundStyle(Color.muted) }
                        Text(L.s("Real blocking", "Настоящая блокировка")).font(.largeTitle.weight(.heavy))
                    }
                    .padding(.top, 8)
                    if store.state.screenTimeReady { readyView } else { setupView }
                }
                .padding(.horizontal, 16).padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
        }
    }

    // MARK: setup

    var setupView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(L.s("iOS Screen Time does the blocking. Unbrick keeps its passcode on this iPhone and only shows it after you pass a Korean session.",
                     "Блокирует сам iOS через «Экранное время». Unbrick хранит код-пароль на этом iPhone и показывает его только после пройденного занятия."))
                .foregroundStyle(Color.muted)
            TipBox(kind: .info, title: L.s("What this build can block", "Что умеет эта сборка"),
                   bodyText: L.s("Unbrick does not close other apps. The tiles on Home are practice shortcuts. Screen Time, which you set up in Settings, is what can limit those apps.",
                                 "Unbrick сам не закрывает другие приложения. Значки на главной — тренировочные ярлыки. Ограничивает их «Экранное время», которое вы включаете в Настройках."))

            if let code {
                VStack(spacing: 6) {
                    Eyebrow(text: L.s("Your Screen Time passcode", "Код-пароль Экранного времени"))
                    Text(code).font(.system(size: 56, weight: .heavy, design: .monospaced)).kerning(12)
                        .foregroundStyle(LinearGradient(colors: [.accent2, .info], startPoint: .leading, endPoint: .trailing))
                    Text(L.s("Type it into Settings below. Don't memorize it — it hides when you finish.", "Введите его в Настройках. Не запоминайте — после настройки он скроется."))
                        .font(.footnote).foregroundStyle(Color.muted).multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity).padding(18).glass()
            } else {
                Button(L.s("Create my Screen Time passcode", "Создать код-пароль")) {
                    let c = ScreenTimeCode.generate(); ScreenTimeCode.set(c); code = c
                }
                .buttonStyle(PrimaryButton())
            }

            if code != nil {
                stepList(L.s("A · Lock Screen Time with the passcode", "A · Защитите Экранное время кодом"), [
                    L.s("Open Settings › Screen Time. If it's off, tap Turn On Screen Time › Continue › This is My iPhone.", "Откройте Настройки › Экранное время. Если выключено: Включить › Продолжить › Это мой iPhone."),
                    L.s("Tap Lock Screen Time Settings (or Use Screen Time Passcode) and enter the code above twice.", "Нажмите «Защитить настройки» (или «Код-пароль Экранного времени») и введите код выше дважды."),
                    L.s("If iOS offers Apple Account recovery for this passcode, you can set it up or skip it. Recovery is how you get Screen Time back if you lose the passcode. Unbrick still only shows the code after a session.", "Если iOS предложит восстановление через Apple ID, его можно включить или пропустить. Так вы вернёте Экранное время, если потеряете код. Unbrick всё равно показывает код только после занятия.")
                ])
                stepList(L.s("B · Block your apps", "B · Заблокируйте приложения"), [
                    L.s("Settings › Screen Time › App Limits › Add Limit.", "Настройки › Экранное время › Лимиты приложений › Добавить лимит."),
                    L.s("Select Social (and Entertainment or Games if you like), or open a category to pick Instagram, TikTok, YouTube… › Next.", "Выберите «Соцсети» (и «Развлечения»/«Игры» по желанию) или отдельные Instagram, TikTok, YouTube… › Далее."),
                    L.s("Set the time to 1 minute, make sure Block at End of Limit is ON, then tap Add.", "Поставьте 1 минуту, включите «Блокировать в конце лимита» и нажмите «Добавить»."),
                    L.s("Optional, stronger: Screen Time › Content & Privacy Restrictions › turn on, so Screen Time can't be switched off without the passcode.", "Для надёжности: Экранное время › Контент и конфиденциальность › включите, чтобы его нельзя было выключить без кода.")
                ])
                if let settings = URL(string: UIApplication.openSettingsURLString) {
                    Link(destination: settings) { Label(L.s("Open Settings", "Открыть Настройки"), systemImage: "gear") }
                        .buttonStyle(GlassButton())
                }
                Button(L.s("I've set the passcode and App Limits", "Код и лимиты настроены")) {
                    store.state.screenTimeReady = true
                    store.flash(L.s("Real blocking is on. The passcode is hidden until you earn an unlock.", "Блокировка включена. Код скрыт до следующей разблокировки."))
                }
                .buttonStyle(DuoButton(color: .good))
            }
        }
    }

    func stepList(_ title: String, _ steps: [String]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.headline)
            ForEach(Array(steps.enumerated()), id: \.offset) { i, s in
                HStack(alignment: .top, spacing: 12) {
                    Text("\(i + 1)").font(.subheadline.monospaced().bold()).foregroundStyle(.white).frame(width: 26, height: 26).background(Circle().fill(brandGradient))
                    Text(s).font(.subheadline).frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(16).glass()
    }

    // MARK: ready

    var readyView: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "lock.shield.fill").font(.title).foregroundStyle(Color.good)
                VStack(alignment: .leading) {
                    Text(L.s("Real blocking is on", "Блокировка включена")).font(.headline)
                    Text(L.s("iOS blocks your apps. The passcode appears on the home screen only while you're unlocked.", "iOS блокирует приложения. Код появляется на главном экране только во время разблокировки."))
                        .font(.footnote).foregroundStyle(Color.muted)
                }
            }
            .padding(16).glass()
            stepList(L.s("How to open a blocked app", "Как открыть заблокированное приложение"), [
                L.s("Pass a session in Unbrick: cards, role-play or the AI tutor.", "Пройдите занятие в Unbrick: карточки, диалог или репетитор."),
                L.s("Unbrick shows your Screen Time passcode for your unlock time.", "Unbrick покажет код-пароль на время разблокировки."),
                L.s("In the blocked app tap Ask for More Time › Enter Screen Time Passcode › Approve for 15 Minutes.", "В заблокированном приложении: «Попросить больше времени» › «Ввести код-пароль» › «Одобрить на 15 минут».")
            ])
            if store.unlocked, let code {
                VStack(spacing: 4) {
                    Eyebrow(text: L.s("Passcode · unlocked now", "Код-пароль · сейчас открыто"))
                    Text(code).font(.system(size: 44, weight: .heavy, design: .monospaced)).kerning(10).foregroundStyle(Color.good)
                }
                .frame(maxWidth: .infinity).padding(16).glass()
                Button(L.s("Change passcode or limits", "Изменить код или лимиты")) { confirmReset = true }.buttonStyle(GlassButton())
            } else {
                TipBox(kind: .info, title: L.s("Changing the setup", "Изменение настроек"),
                       bodyText: L.s("To change the passcode or your limits, pass a session first — Screen Time asks for the current passcode.", "Чтобы изменить код или лимиты, сначала пройдите занятие — Экранное время спросит текущий код."))
            }
        }
        .confirmationDialog(L.s("Start over with a new passcode? Change it in Settings › Screen Time › Change Screen Time Passcode while the current one is shown.", "Создать новый код? Смените его в Настройки › Экранное время › Сменить код-пароль, пока текущий виден."),
                            isPresented: $confirmReset, titleVisibility: .visible) {
            Button(L.s("New passcode", "Новый код"), role: .destructive) {
                let old = code ?? ""
                let c = ScreenTimeCode.generate(); ScreenTimeCode.set(c); code = c
                store.state.screenTimeReady = false
                store.flash(L.s("Old passcode: \(old). Enter it, then the new one, in Screen Time.", "Старый код: \(old). Введите его, затем новый, в Экранном времени."))
            }
        }
    }
}
