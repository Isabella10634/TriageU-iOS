import Foundation
import UserNotifications

/// Recordatorios locales de entrega.
/// - Sin hora definida: día anterior y día de la entrega, a las horas configuradas en Perfil.
/// - Con hora definida: 24 h y 2 h antes de la hora exacta.
/// - Prioridad ALTA: aviso extra 3 días antes.
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
        ["3d", "1d", "0d", "24h", "2h"].map { "\(id.uuidString)-\($0)" }
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
        var fires: [(suffix: String, date: Date, body: String)] = []
        let title = activity.title

        if activity.hasDueTime {
            let due = activity.dueDate
            if activity.priority == "ALTA",
               let d = cal.date(byAdding: .day, value: -3, to: due) {
                fires.append(("3d", d, "Prioridad alta: \(title) vence en 3 días"))
            }
            if let d = cal.date(byAdding: .hour, value: -24, to: due) {
                fires.append(("24h", d, "Vence en 24 horas: \(title)"))
            }
            if let d = cal.date(byAdding: .hour, value: -2, to: due) {
                fires.append(("2h", d, "Vence en 2 horas: \(title)"))
            }
        } else {
            let hourBefore = hour(hourBeforeKey, default: 9)
            let hourDay = hour(hourDayKey, default: 8)
            let dueDay = cal.startOfDay(for: activity.dueDate)

            func at(_ daysBefore: Int, _ hour: Int) -> Date? {
                guard let day = cal.date(byAdding: .day, value: -daysBefore, to: dueDay) else { return nil }
                return cal.date(bySettingHour: hour, minute: 0, second: 0, of: day)
            }
            if activity.priority == "ALTA", let d = at(3, hourBefore) {
                fires.append(("3d", d, "Prioridad alta: \(title) vence en 3 días"))
            }
            if let d = at(1, hourBefore) { fires.append(("1d", d, "Mañana vence: \(title)")) }
            if let d = at(0, hourDay) { fires.append(("0d", d, "Hoy vence: \(title)")) }
        }

        for item in fires where item.date > Date() {
            let content = UNMutableNotificationContent()
            content.title = activity.subject
            content.body = item.body
            content.sound = .default

            let comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: item.date)
            let request = UNNotificationRequest(
                identifier: "\(activity.id.uuidString)-\(item.suffix)",
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            )
            try? await UNUserNotificationCenter.current().add(request)
        }
    }

    static func rescheduleAll(_ activities: [TriageActivity]) async {
        for a in activities { await schedule(for: a) }
    }
}
