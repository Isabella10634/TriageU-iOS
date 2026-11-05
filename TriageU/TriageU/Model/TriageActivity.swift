import Foundation
import SwiftData

@Model
final class TriageActivity {
    var id: UUID
    var title: String
    var subject: String
    var type: String
    var dueDate: Date
    var weightPercent: Int?
    var preparation: Int
    var durationMin: Int
    var priority: String
    var completed: Bool
    var createdAt: Date
    var updatedAt: Date = Date()

    init(
        title: String,
        subject: String,
        type: String,
        dueDate: Date,
        weightPercent: Int?,
        preparation: Int,
        durationMin: Int,
        priority: String,
        completed: Bool = false
    ) {
        self.id = UUID()
        self.title = title
        self.subject = subject
        self.type = type
        self.dueDate = dueDate
        self.weightPercent = weightPercent
        self.preparation = preparation
        self.durationMin = durationMin
        self.priority = priority
        self.completed = completed
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    /// Marca la actividad como modificada ahora (para resolver conflictos).
    func touch() { updatedAt = Date() }
}
