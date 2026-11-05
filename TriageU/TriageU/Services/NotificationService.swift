import Foundation
import UserNotifications

/// Recordatorios locales de entrega (horas configurables en Perfil).
/// - Día anterior (por defecto 9:00)
/// - Día de la entrega (por defecto 8:00)
/// - Prioridad ALTA: además, 3 días antes a la hora del día anterior
enum NotificationService {

    static let hourBeforeKey = "reminderHourBefore"
    static let hourDayKey = "reminderHourDay"

    private static func hour(_ key: String, default value: Int) -> Int {
        UserDefaults.standard.object(forKey: key) as? Int ?? value
    }

    final class Delegate: NSObject, UNUserNotificationCenterDelegate {
        func userNotificationCenter(
            _ center: UNUserNotificationCenter,
            willPresent notification: UNNotification
        ) async -> UNNotificationPresentationOptions {
            [.banner, .sound]
        }
    }

    static let delegate = Delegate()

    static func configure() {
        UNUserNotificationCenter.current().delegate = delegate
    }

    static func requestAuthorization() async {
        _ = try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge])
    }

    private static func identifiers(for id: UUID) -> [String] {
        ["\(id.uuidString)-3d", "\(id.uuidString)-1d", "\(id.uuidString)-0d"]
    }

    static func cancel(id: UUID) {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: identifiers(for: id))
    }

    static func cancelAll() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    static func schedule(for activity: TriageActivity) async {
        cancel(id: activity.id)
        guard !activity.completed else { return }

        let cal = Calendar.current
        let dueDay = cal.startOfDay(for: activity.dueDate)

        let hourBefore = hour(hourBeforeKey, default: 9)
        let hourDay = hour(hourDayKey, default: 8)

        var plan: [(suffix: String, daysBefore: Int, hour: Int, body: String)] = [
            ("1d", 1, hourBefore, "Mañana vence: \(activity.title)"),
            ("0d", 0, hourDay, "Hoy vence: \(activity.title)")
        ]
        if activity.priority == "ALTA" {
            plan.insert(("3d", 3, hourBefore, "Prioridad alta: \(activity.title) vence en 3 días"), at: 0)
        }

        for item in plan {
            guard let day = cal.date(byAdding: .day, value: -item.daysBefore, to: dueDay),
                  let fire = cal.date(bySettingHour: item.hour, minute: 0, second: 0, of: day),
                  fire > Date() else { continue }

            let content = UNMutableNotificationContent()
            content.title = activity.subject
            content.body = item.body
            content.sound = .default

            let comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            let request = UNNotificationRequest(
                identifier: "\(activity.id.uuidString)-\(item.suffix)",
                content: content,
                trigger: trigger
            )
            try? await UNUserNotificationCenter.current().add(request)
        }
    }

    static func rescheduleAll(_ activities: [TriageActivity]) async {
        for a in activities { await schedule(for: a) }
    }
}
