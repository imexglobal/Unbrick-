import SwiftUI

/// In-app summary of web/privacy.html. The store listing needs the hosted page; this covers TestFlight builds before that URL is set.
struct PrivacyView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                AuroraBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        Text(L.s("Unbrick stores your study progress on this iPhone. It does not have an account, and it does not sell or track data.",
                                 "Unbrick хранит прогресс учёбы на этом iPhone. Аккаунта нет, данные не продаются и не используются для слежки."))
                        group(L.s("On this iPhone", "На этом iPhone"), [
                            L.s("Lesson scores, streak, and the apps you marked for practice stay in the app's files.", "Оценки, серия дней и отмеченные для тренировки приложения лежат в файлах приложения."),
                            L.s("A Screen Time passcode, if you create one, stays in the Keychain. It is not uploaded.", "Код-пароль Экранного времени, если вы его создали, остаётся в Связке ключей и не отправляется."),
                            L.s("The microphone records a short clip so you can replay your voice. Speech Recognition turns it into text. When the Korean on-device model is installed, that stays on the phone; otherwise Apple may process the audio.", "Микрофон пишет короткий фрагмент, чтобы вы могли его прослушать. Распознавание речи делает из него текст. Если корейская модель установлена на устройстве, это остаётся на телефоне; иначе аудио может обработать Apple.")
                        ])
                        group(L.s("Claude", "Claude"), [
                            L.s("When this build includes the Unbrick server, the text of an answer and the lesson prompt are sent there so Claude can reply. The audio file is not sent. The server is not meant to store the text.", "Если в сборке указан сервер Unbrick, текст ответа и задание урока отправляются туда, чтобы ответил Claude. Аудиофайл не отправляется. Сервер не должен хранить этот текст."),
                            L.s("Until that server is configured, Claude is off. Apple Intelligence, if you turn it on, checks answers on the device.", "Пока сервер не настроен, Claude выключен. Apple Intelligence, если он включён, проверяет ответы на устройстве.")
                        ])
                        group(L.s("Notifications", "Уведомления"), [
                            L.s("If you allow notifications, Unbrick schedules one local alert for when an unlock window ends. There is no remote push.", "Если разрешить уведомления, Unbrick ставит одно локальное напоминание об окончании разблокировки. Удалённых push-уведомлений нет.")
                        ])
                        if let url = ProxyConfig.privacyURL {
                            Link(destination: url) { Label(L.s("Full policy", "Полный текст"), systemImage: "safari") }
                                .buttonStyle(GlassButton())
                        } else {
                            Text(L.s("The public policy page is not linked in this build yet.", "Публичная страница политики в этой сборке ещё не указана."))
                                .font(.footnote).foregroundStyle(Color.muted)
                        }
                    }
                    .padding(16)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle(L.s("Privacy", "Конфиденциальность"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L.s("Done", "Готово")) { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    func group(_ title: String, _ lines: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            ForEach(lines, id: \.self) { line in
                Text(line).font(.subheadline).foregroundStyle(Color.muted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14).glass()
    }
}
