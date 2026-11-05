import SwiftUI
import SwiftData

/// Administración de materias (crear, renombrar, cambiar color, eliminar).
struct SubjectsView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \Subject.name) private var subjects: [Subject]
    @Query private var activities: [TriageActivity]

    @State private var editing: Subject?
    @State private var showNew = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(subjects) { subject in
                    Button { editing = subject } label: {
                        HStack(spacing: 12) {
                            Circle().fill(subject.color).frame(width: 14, height: 14)
                            Text(subject.name).foregroundStyle(Color.primary)
                            Spacer()
                            Text("\(activities.filter { $0.subject == subject.name }.count)")
                                .foregroundStyle(textSecondary)
                        }
                    }
                }
                .onDelete(perform: delete)

                if subjects.isEmpty {
                    Text("No tienes materias. Agrega una con el botón +.")
                        .foregroundStyle(textSecondary)
                }
            }
            .navigationTitle("Mis materias")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button { showNew = true } label: { Image(systemName: "plus") }
                }
            }
            .sheet(item: $editing) { subject in
                SubjectEditor(subject: subject)
            }
            .sheet(isPresented: $showNew) {
                SubjectEditor(subject: nil)
            }
        }
        .tint(triageGreen)
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            let subject = subjects[index]
            let id = subject.id
            modelContext.delete(subject)
            Task { await SupabaseService.deleteSubject(id: id) }
        }
        try? modelContext.save()
    }
}

private struct SubjectEditor: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query private var allSubjects: [Subject]
    @Query private var activities: [TriageActivity]

    let subject: Subject?

    @State private var name: String
    @State private var colorHex: String

    init(subject: Subject?) {
        self.subject = subject
        _name = State(initialValue: subject?.name ?? "")
        _colorHex = State(initialValue: subject?.colorHex ?? SubjectDefaults.palette[0])
    }

    private var cleanName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isDuplicate: Bool {
        allSubjects.contains {
            $0.id != subject?.id && $0.name.lowercased() == cleanName.lowercased()
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Nombre") {
                    TextField("Ej. Bases de Datos", text: $name)
                    if isDuplicate {
                        Text("Ya existe una materia con ese nombre.")
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
                Section("Color") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 14) {
                        ForEach(SubjectDefaults.palette, id: \.self) { hex in
                            Circle()
                                .fill(Color(hex: hex))
                                .frame(width: 38, height: 38)
                                .overlay {
                                    if hex == colorHex {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(.white)
                                            .font(.system(size: 15, weight: .bold))
                                    }
                                }
                                .onTapGesture { colorHex = hex }
                        }
                    }
                    .padding(.vertical, 6)
                }
            }
            .navigationTitle(subject == nil ? "Nueva materia" : "Editar materia")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") { save() }
                        .disabled(cleanName.isEmpty || isDuplicate)
                }
            }
        }
        .tint(triageGreen)
    }

    private func save() {
        if let subject {
            let oldName = subject.name
            subject.name = cleanName
            subject.colorHex = colorHex
            subject.touch()

            // Las actividades guardan la materia por nombre: se renombran también.
            if oldName != cleanName {
                for a in activities where a.subject == oldName {
                    a.subject = cleanName
                    a.touch()
                    Task { await SupabaseService.upsert(a) }
                }
            }
            try? modelContext.save()
            Task { await SupabaseService.upsert(subject) }
        } else {
            let new = Subject(name: cleanName, colorHex: colorHex)
            modelContext.insert(new)
            try? modelContext.save()
            Task { await SupabaseService.upsert(new) }
        }
        dismiss()
    }
}
