import Foundation


enum ActivityFormValidator {


    static func validate(
        title: String,
        subject: String,
        weight: String,
        estimatedHours: Int,
        preparation: Int
    ) -> String? {


        let cleanTitle = title.trimmingCharacters(
            in: .whitespacesAndNewlines
        )


        let cleanSubject = subject.trimmingCharacters(
            in: .whitespacesAndNewlines
        )


        let cleanWeight = weight.trimmingCharacters(
            in: .whitespacesAndNewlines
        )


        guard !cleanTitle.isEmpty else {
            return "Escribe el nombre de la actividad."
        }


        guard !cleanSubject.isEmpty else {
            return "Crea una materia primero (Perfil > Mis materias)."
        }


        if !cleanWeight.isEmpty {
            guard let percentage = Int(cleanWeight),
                  (0...100).contains(percentage) else {
                return "El porcentaje debe ser un número entre 0 y 100."
            }
        }


        guard estimatedHours > 0 else {
            return "La duración debe ser mayor que cero."
        }


        guard (1...5).contains(preparation) else {
            return "El nivel de preparación debe estar entre 1 y 5."
        }


        return nil
    }
}
