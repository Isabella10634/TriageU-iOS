import Foundation
import Observation
import SwiftData

@Observable
final class TriageViewModel {

    // MARK: - Datos del formulario

    var newActivityTitle: String = ""
    var newActivitySubject: String = ""
    var newActivityType: String = "Parcial"
    var newActivityDate: Date = Date()
    var newActivityHasTime: Bool = false
    var newActivityWeight: String = ""
    var newActivityPreparation: Int = 3
    var newActivityEstimatedHours: Int = 4

    var lastMessage: String?

    let activityTypes = [
        "Parcial",
        "Tarea",
        "Proyecto",
        "Exposición",
        "Otro"
    ]

    // MARK: - Prioridad

    func calculatePriority(
        preparation: Int,
        weight: Int?
    ) -> String {

        let activityWeight = weight ?? 0

        if preparation <= 2 || activityWeight >= 30 {
            return "ALTA"
        }

        if preparation == 3 || activityWeight >= 15 {
            return "MEDIA"
        }

        return "BAJA"
    }

    // MARK: - Guardar actividad

    func saveActivity(context: ModelContext) {

        let cleanTitle =
            newActivityTitle.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        guard !cleanTitle.isEmpty else {
            lastMessage = "Escribe el nombre de la actividad."
            return
        }

        guard !newActivitySubject.isEmpty else {
            lastMessage = "Crea una materia primero (Perfil > Mis materias)."
            return
        }

        let weight = Int(newActivityWeight)
        let due = newActivityHasTime
            ? newActivityDate
            : Calendar.current.startOfDay(for: newActivityDate)

        let priority = calculatePriority(
            preparation: newActivityPreparation,
            weight: weight
        )

        let activity = TriageActivity(
            title: cleanTitle,
            subject: newActivitySubject,
            type: newActivityType,
            dueDate: due,
            weightPercent: weight,
            preparation: newActivityPreparation,
            durationMin: newActivityEstimatedHours * 60,
            priority: priority,
            hasDueTime: newActivityHasTime
        )

        context.insert(activity)

        do {
            try context.save()
            Task {
                await SupabaseService.upsert(activity)
                await NotificationService.schedule(for: activity)
            }
            lastMessage = "Actividad guardada correctamente."
            resetForm()
        } catch {
            lastMessage = "No fue posible guardar la actividad."
        }
    }

    // MARK: - Limpiar formulario

    func resetForm() {
        newActivityTitle = ""
        newActivityType = "Parcial"
        newActivityDate = Date()
        newActivityHasTime = false
        newActivityWeight = ""
        newActivityPreparation = 3
        newActivityEstimatedHours = 4
    }
}
