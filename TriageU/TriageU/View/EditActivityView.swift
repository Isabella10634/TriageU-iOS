import SwiftUI
import SwiftData

struct EditActivityView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let activity: TriageActivity

    @State private var title: String
    @State private var subject: String
    @State private var type: String
    @State private var dueDate: Date
    @State private var weight: String
    @State private var preparation: Int
    @State private var hours: Int

    private let helper = TriageViewModel()

    init(activity: TriageActivity) {
        self.activity = activity
        _title = State(initialValue: activity.title)
        _subject = State(initialValue: activity.subject)
        _type = State(initialValue: activity.type)
        _dueDate = State(initialValue: activity.dueDate)
        _weight = State(initialValue: activity.weightPercent.map(String.init) ?? "")
        _preparation = State(initialValue: activity.preparation)
        _hours = State(initialValue: max(1, activity.durationMin / 60))
    }

    private var subjects: [String] {
        helper.subjects.contains(subject) ? helper.subjects : helper.subjects + [subject]
    }

    private var types: [String] {
        helper.activityTypes.contains(type) ? helper.activityTypes : helper.activityTypes + [type]
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Información básica") {
                    Picker("Materia", selection: $subject) {
                        ForEach(subjects, id: \.self) { Text($0).tag($0) }
                    }
                    TextField("Actividad", text: $title)
                    Picker("Tipo", selection: $type) {
                        ForEach(types, id: \.self) { Text($0).tag($0) }
                    }
                    DatePicker("Fecha", selection: $dueDate, displayedComponents: .date)
                }

                Section("Priorización") {
                    HStack {
                        TextField("Peso (opcional)", text: $weight)
                            .keyboardType(.numberPad)
                        Text("%").foregroundStyle(textSecondary)
                    }
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Preparación")
                        PreparationSelector(value: $preparation)
                    }
                    Stepper("Tiempo estimado: \(hours) h", value: $hours, in: 1...12)
                }
            }
            .navigationTitle("Editar actividad")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") { save() }
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .tint(triageGreen)
    }

    private func save() {
        let weightValue = Int(weight)
        activity.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        activity.subject = subject
        activity.type = type
        activity.dueDate = dueDate
        activity.weightPercent = weightValue
        activity.preparation = preparation
        activity.durationMin = hours * 60
        activity.priority = helper.calculatePriority(preparation: preparation, weight: weightValue)
        activity.touch()
        try? modelContext.save()

        Task {
            await SupabaseService.upsert(activity)
            await NotificationService.schedule(for: activity)
        }
        dismiss()
    }
}
