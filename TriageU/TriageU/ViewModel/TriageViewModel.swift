import Foundation
import Observation
import SwiftData

@Observable
final class TriageViewModel {

    // MARK: - Datos del formulario

    var newActivityTitle: String = ""
    var newActivitySubject: String = "Comunicaciones Móviles"
    var newActivityType: String = "Parcial"
    var newActivityDate: Date = Date()
    var newActivityWeight: String = ""
    var newActivityPreparation: Int = 3
    var newActivityEstimatedHours: Int = 4

    var lastMessage: String?

    let subjects = [
        "Comunicaciones Móviles",
        "Aplicaciones Móviles",
        "Entornos Inteligentes"
    ]

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

        let weight = Int(newActivityWeight)

        let priority = calculatePriority(
            preparation: newActivityPreparation,
            weight: weight
        )

        let activity = TriageActivity(
            title: cleanTitle,
            subject: newActivitySubject,
            type: newActivityType,
            dueDate: newActivityDate,
            weightPercent: weight,
            preparation: newActivityPreparation,
            durationMin: newActivityEstimatedHours * 60,
            priority: priority
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
        newActivityWeight = ""
        newActivityPreparation = 3
        newActivityEstimatedHours = 4
    }
}
