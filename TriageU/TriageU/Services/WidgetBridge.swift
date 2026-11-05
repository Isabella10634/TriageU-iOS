import Foundation
import WidgetKit

/// Publica un resumen de las actividades pendientes para el widget (vía App Group).
enum WidgetBridge {

    static let groupId = "group.edu.unicauca.aplimovil.TriageU"
    static let key = "widgetItems"

    struct Item: Codable {
        var id: UUID
        var title: String
        var subject: String
        var colorHex: String
        var dueDate: Date
        var hasDueTime: Bool
        var priority: String
    }

    static func update(activities: [TriageActivity], subjects: [Subject]) {
        let colors = Dictionary(subjects.map { ($0.name, $0.colorHex) }, uniquingKeysWith: { a, _ in a })
        let items = activities
            .filter { !$0.completed }
            .sorted { $0.dueDate < $1.dueDate }
            .prefix(6)
            .map {
                Item(id: $0.id, title: $0.title, subject: $0.subject,
                     colorHex: colors[$0.subject] ?? "#4F7A68",
                     dueDate: $0.dueDate, hasDueTime: $0.hasDueTime, priority: $0.priority)
            }
        guard let defaults = UserDefaults(suiteName: groupId),
              let data = try? JSONEncoder().encode(Array(items)) else { return }
        defaults.set(data, forKey: key)
        WidgetCenter.shared.reloadAllTimelines()
    }

    static func clear() {
        UserDefaults(suiteName: groupId)?.removeObject(forKey: key)
        WidgetCenter.shared.reloadAllTimelines()
    }
}
