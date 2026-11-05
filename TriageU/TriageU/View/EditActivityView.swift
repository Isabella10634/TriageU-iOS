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
    @State private var hasTime: Bool
    @State private var weight: String
    @State private var preparation: Int
    @State private var hours: Int


    @Query(sort: \Subject.name) private var subjectList: [Subject]


    private let helper = TriageViewModel()


    private var validationError: String? {
        ActivityFormValidator.validate(
            title: title,
            subject: subject,
            weight: weight,
            estimatedHours: hours,
            preparation: preparation
        )
    }


    init(activity: TriageActivity) {
        self.activity = activity
        _title = State(initialValue: activity.title)
        _subject = State(initialValue: activity.subject)
        _type = State(initialValue: activity.type)
        _dueDate = State(initialValue: activity.dueDate)
        _hasTime = State(initialValue: activity.hasDueTime)
        _weight = State(initialValue: activity.weightPercent.map(String.init) ?? "")
        _preparation = State(initialValue: activity.preparation)
        _hours = State(initialValue: max(1, activity.durationMin / 60))
    }


    private var subjects: [String] {
        let names = subjectList.map(\.name)
        return names.contains(subject) ? names : names + [subject]
    }


    private var types: [String] {
        helper.activityTypes.contains(type)
            ? helper.activityTypes
            : helper.activityTypes + [type]
    }


    var body: some View {
        NavigationStack {
            Form {
                Section("Información básica") {
                    Picker("Materia", selection: $subject) {
                        ForEach(subjects, id: \.self) {
                            Text($0).tag($0)
                        }
                    }


                    TextField("Actividad", text: $title)


                    Picker("Tipo", selection: $type) {
                        ForEach(types, id: \.self) {
                            Text($0).tag($0)
                        }
                    }


                    DatePicker(
                        "Fecha",
                        selection: $dueDate,
                        displayedComponents: .date
                    )


                    Toggle("Definir hora de entrega", isOn: $hasTime)


                    if hasTime {
                        DatePicker(
                            "Hora",
                            selection: $dueDate,
                            displayedComponents: .hourAndMinute
                        )
                    }
                }


                Section("Priorización") {
                    HStack {
                        TextField("Peso (opcional)", text: $weight)
                            .keyboardType(.numberPad)


                        Text("%")
                            .foregroundStyle(textSecondary)
                    }


                    VStack(alignment: .leading, spacing: 10) {
                        Text("Preparación")
                        PreparationSelector(value: $preparation)
                    }


                    Stepper(
                        "Tiempo estimado: \(hours) h",
                        value: $hours,
                        in: 1...12
                    )
                }


                if let validationError {
                    Section {
                        Label(
                            validationError,
                            systemImage: "exclamationmark.circle"
                        )
                        .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Editar actividad")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") {
                        dismiss()
                    }
                }


                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        save()
                    }
                    .disabled(validationError != nil)
                }
            }
        }
        .tint(triageGreen)
    }


    private func save() {
        guard validationError == nil else {
            return
        }


        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanSubject = subject.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanWeight = weight.trimmingCharacters(in: .whitespacesAndNewlines)


        let weightValue = cleanWeight.isEmpty ? nil : Int(cleanWeight)


        activity.title = cleanTitle
        activity.subject = cleanSubject
        activity.type = type
        activity.dueDate = hasTime
            ? dueDate
            : Calendar.current.startOfDay(for: dueDate)
        activity.hasDueTime = hasTime
        activity.weightPercent = weightValue
        activity.preparation = preparation
        activity.durationMin = hours * 60


        activity.priority = helper.calculatePriority(
            preparation: preparation,
            weight: weightValue
        )


        activity.touch()


        do {
            try modelContext.save()


            Task {
                await SupabaseService.upsert(activity)
                await NotificationService.schedule(for: activity)
            }


            dismiss()
        } catch {
            print("Error al guardar la actividad: \(error.localizedDescription)")
        }
    }
}
