import SwiftUI
import SwiftData

private let triageGreen = Color(
    red: 79.0 / 255.0,
    green: 122.0 / 255.0,
    blue: 104.0 / 255.0
)

private let softGreen = Color(
    red: 234.0 / 255.0,
    green: 244.0 / 255.0,
    blue: 238.0 / 255.0
)

struct ContentView: View {

    @State private var viewModel = TriageViewModel()

    var body: some View {

        TabView {

            TodayView()
                .tabItem {
                    Label("Hoy", systemImage: "house.fill")
                }

            RouteView()
                .tabItem {
                    Label("Mi Ruta", systemImage: "point.topleft.down.to.point.bottomright.curvepath")
                }

            NewActivityView(viewModel: viewModel)
                .tabItem {
                    Label("Nueva", systemImage: "plus.circle.fill")
                }

            TriageProgressView()
                .tabItem {
                    Label("Progreso", systemImage: "chart.line.uptrend.xyaxis")
                }

            ProfileView()
                .tabItem {
                    Label("Perfil", systemImage: "person.fill")
                }
        }
        .tint(triageGreen)
    }
}


// MARK: - HOY

struct TodayView: View {

    @Environment(\.modelContext)
    private var modelContext

    @Query(
        sort: \TriageActivity.createdAt,
        order: .reverse
    )
    private var activities: [TriageActivity]

    var body: some View {

        NavigationStack {

            ScrollView {

                VStack(
                    alignment: .leading,
                    spacing: 20
                ) {

                    Text("¡Buenos días!")
                        .font(.largeTitle)
                        .bold()

                    Text("Organiza tus actividades académicas")
                        .foregroundStyle(.secondary)

                    VStack(
                        alignment: .leading,
                        spacing: 6
                    ) {

                        Text("Hoy tienes:")
                            .bold()
                            .foregroundStyle(triageGreen)

                        Text(
                            "\(activities.filter { !$0.completed }.count) actividades pendientes"
                        )
                    }
                    .frame(
                        maxWidth: .infinity,
                        alignment: .leading
                    )
                    .padding()
                    .background(softGreen)
                    .clipShape(
                        RoundedRectangle(
                            cornerRadius: 18
                        )
                    )

                    Text("Tu plan recomendado")
                        .font(.title2)
                        .bold()

                    if activities.isEmpty {

                        VStack(spacing: 12) {

                            Image(
                                systemName: "checklist"
                            )
                            .font(.system(size: 40))
                            .foregroundStyle(triageGreen)

                            Text(
                                "Todavía no tienes actividades."
                            )
                            .font(.headline)

                            Text(
                                "Agrégalas desde la pestaña Nueva."
                            )
                            .foregroundStyle(.secondary)
                        }
                        .frame(
                            maxWidth: .infinity
                        )
                        .padding(.vertical, 40)

                    } else {

                        ForEach(activities) { activity in

                            ActivityCard(
                                activity: activity,
                                onToggle: {

                                    activity.completed.toggle()

                                    try? modelContext.save()
                                }
                            )
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("")
        }
    }
}


// MARK: - TARJETA ACTIVIDAD

struct ActivityCard: View {

    let activity: TriageActivity
    let onToggle: () -> Void

    var priorityColor: Color {

        switch activity.priority {

        case "ALTA":
            return .red

        case "MEDIA":
            return .orange

        default:
            return .secondary
        }
    }

    var body: some View {

        HStack(
            alignment: .top,
            spacing: 14
        ) {

            VStack(
                alignment: .leading,
                spacing: 8
            ) {

                Text(
                    "PRIORIDAD \(activity.priority)"
                )
                .font(.caption)
                .bold()
                .foregroundStyle(priorityColor)

                Text(activity.title)
                    .font(.title3)
                    .bold()

                Text(activity.subject)
                    .foregroundStyle(triageGreen)

                Text(
                    "\(activity.durationMin) min recomendados"
                )
                .foregroundStyle(.secondary)

                if let weight =
                    activity.weightPercent {

                    Text(
                        "\(weight) % de la nota"
                    )
                    .foregroundStyle(.secondary)
                }

                Text(
                    "Preparación: \(activity.preparation)/5"
                )
                .foregroundStyle(.secondary)
            }

            Spacer()

            Button(action: onToggle) {

                Image(
                    systemName:
                        activity.completed
                        ? "checkmark.circle.fill"
                        : "circle"
                )
                .font(.title)
                .foregroundStyle(triageGreen)
            }
        }
        .padding()
        .background(Color.white)
        .overlay {

            RoundedRectangle(
                cornerRadius: 18
            )
            .stroke(
                Color.gray.opacity(0.25)
            )
        }
        .clipShape(
            RoundedRectangle(
                cornerRadius: 18
            )
        )
    }
}


// MARK: - NUEVA ACTIVIDAD

struct NewActivityView: View {

    @Environment(\.modelContext)
    private var modelContext

    @Bindable var viewModel: TriageViewModel

    var body: some View {

        NavigationStack {

            Form {

                Section("Información básica") {

                    Picker(
                        "Materia",
                        selection:
                            $viewModel.newActivitySubject
                    ) {

                        ForEach(
                            viewModel.subjects,
                            id: \.self
                        ) { subject in

                            Text(subject)
                                .tag(subject)
                        }
                    }

                    TextField(
                        "Nombre de la actividad",
                        text:
                            $viewModel.newActivityTitle
                    )

                    Picker(
                        "Tipo",
                        selection:
                            $viewModel.newActivityType
                    ) {

                        ForEach(
                            viewModel.activityTypes,
                            id: \.self
                        ) { type in

                            Text(type)
                                .tag(type)
                        }
                    }

                    DatePicker(
                        "Fecha",
                        selection:
                            $viewModel.newActivityDate,
                        displayedComponents:
                            .date
                    )
                }

                Section("Ayúdanos a priorizarla") {

                    TextField(
                        "Peso en la materia (%)",
                        text:
                            $viewModel.newActivityWeight
                    )
                    .keyboardType(.numberPad)

                    Stepper(
                        "Preparación: \(viewModel.newActivityPreparation)/5",
                        value:
                            $viewModel.newActivityPreparation,
                        in: 1...5
                    )

                    Stepper(
                        "Tiempo estimado: \(viewModel.newActivityEstimatedHours) h",
                        value:
                            $viewModel.newActivityEstimatedHours,
                        in: 1...12
                    )
                }

                Section {

                    Button {

                        viewModel.saveActivity(
                            context: modelContext
                        )

                    } label: {

                        Text("Guardar actividad")
                            .frame(
                                maxWidth: .infinity
                            )
                            .bold()
                    }
                    .foregroundStyle(triageGreen)

                    if let message =
                        viewModel.lastMessage {

                        Text(message)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle(
                "Nueva actividad"
            )
        }
    }
}


// MARK: - MI RUTA

struct RouteView: View {

    @Query(
        sort: \TriageActivity.dueDate
    )
    private var activities: [TriageActivity]

    var body: some View {

        NavigationStack {

            ScrollView {

                VStack(
                    alignment: .leading,
                    spacing: 22
                ) {

                    Text("Próximas actividades")
                        .foregroundStyle(.secondary)

                    if activities.isEmpty {

                        Text(
                            "Agrega actividades para construir tu ruta."
                        )
                        .foregroundStyle(.secondary)
                        .padding(.top)

                    } else {

                        ForEach(activities) {
                            activity in

                            HStack(
                                alignment: .top,
                                spacing: 16
                            ) {

                                Circle()
                                    .fill(triageGreen)
                                    .frame(
                                        width: 18,
                                        height: 18
                                    )

                                VStack(
                                    alignment: .leading,
                                    spacing: 5
                                ) {

                                    Text(
                                        activity.dueDate,
                                        style: .date
                                    )
                                    .font(.caption)
                                    .foregroundStyle(
                                        triageGreen
                                    )

                                    Text(
                                        activity.title
                                    )
                                    .font(.headline)

                                    Text(
                                        activity.subject
                                    )
                                    .foregroundStyle(
                                        .secondary
                                    )

                                    Text(
                                        activity.type
                                    )
                                    .font(.caption)
                                }

                                Spacer()
                            }
                        }
                    }
                }
                .frame(
                    maxWidth: .infinity,
                    alignment: .leading
                )
                .padding()
            }
            .navigationTitle("Mi Ruta")
        }
    }
}


// MARK: - PROGRESO

struct TriageProgressView: View {

    @Query
    private var activities:
        [TriageActivity]

    private var completed: Int {

        activities.filter {
            $0.completed
        }.count
    }

    private var progress: Double {

        guard !activities.isEmpty else {
            return 0
        }

        return Double(completed)
            / Double(activities.count)
    }

    var body: some View {

        NavigationStack {

            ScrollView {

                VStack(
                    alignment: .leading,
                    spacing: 25
                ) {

                    Text("Avanza a tu ritmo")
                        .foregroundStyle(.secondary)

                    Text("ESTA SEMANA")
                        .font(.headline)

                    HStack {

                        Text(
                            "\(completed) de \(activities.count) actividades realizadas"
                        )

                        Spacer()

                        Text(
                            "\(Int(progress * 100)) %"
                        )
                        .bold()
                        .foregroundStyle(triageGreen)
                    }

                    SwiftUI.ProgressView(
                        value: progress
                    )
                    .tint(triageGreen)

                    VStack(
                        alignment: .leading,
                        spacing: 8
                    ) {

                        Text(
                            "\(activities.count) actividades registradas"
                        )
                        .font(.title3)

                        Text(
                            "\(activities.count - completed) pendientes"
                        )
                        .font(.title3)
                    }

                    VStack(
                        alignment: .leading,
                        spacing: 8
                    ) {

                        Text("Buen avance")
                            .font(.headline)

                        Text(
                            "Continúa organizando tus actividades y completando tus pendientes."
                        )
                        .foregroundStyle(.secondary)
                    }
                    .padding()
                    .frame(
                        maxWidth: .infinity,
                        alignment: .leading
                    )
                    .overlay {

                        RoundedRectangle(
                            cornerRadius: 18
                        )
                        .stroke(
                            Color.gray.opacity(0.25)
                        )
                    }
                }
                .padding()
            }
            .navigationTitle(
                "Mi progreso"
            )
        }
    }
}


// MARK: - PERFIL

struct ProfileView: View {

    var body: some View {

        NavigationStack {

            VStack(spacing: 25) {

                Image(
                    systemName:
                        "person.circle.fill"
                )
                .font(.system(size: 85))
                .foregroundStyle(triageGreen)

                Text("Estudiante TriageU")
                    .font(.title2)
                    .bold()

                Text(
                    "Prioriza tu tiempo. Avanza a tu ritmo."
                )
                .foregroundStyle(.secondary)

                VStack(
                    alignment: .leading,
                    spacing: 12
                ) {

                    Text("Mis materias")
                        .font(.headline)

                    Text(
                        "• Aplicaciones Móviles"
                    )

                    Text(
                        "• Comunicaciones Móviles"
                    )

                    Text(
                        "• Entornos Inteligentes"
                    )
                }
                .frame(
                    maxWidth: .infinity,
                    alignment: .leading
                )
                .padding()
                .overlay {

                    RoundedRectangle(
                        cornerRadius: 18
                    )
                    .stroke(
                        Color.gray.opacity(0.25)
                    )
                }

                NavigationLink {

                    AboutView()

                } label: {

                    HStack {

                        Image(
                            systemName:
                                "info.circle.fill"
                        )
                        .foregroundStyle(
                            triageGreen
                        )

                        VStack(
                            alignment: .leading
                        ) {

                            Text(
                                "Acerca de TriageU"
                            )
                            .bold()

                            Text(
                                "Descripción y créditos"
                            )
                            .font(.caption)
                            .foregroundStyle(
                                .secondary
                            )
                        }

                        Spacer()

                        Image(
                            systemName:
                                "chevron.right"
                        )
                    }
                    .padding()
                }
                .buttonStyle(.plain)
                .overlay {

                    RoundedRectangle(
                        cornerRadius: 18
                    )
                    .stroke(
                        Color.gray.opacity(0.25)
                    )
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Perfil")
        }
    }
}


// MARK: - ACERCA DE

struct AboutView: View {

    var body: some View {

        ScrollView {

            VStack(
                alignment: .leading,
                spacing: 22
            ) {

                Text("TriageU")
                    .font(.largeTitle)
                    .bold()
                    .foregroundStyle(
                        triageGreen
                    )

                Text(
                    "Prioriza tu tiempo. Avanza a tu ritmo."
                )
                .foregroundStyle(.secondary)

                Text("¿Qué es TriageU?")
                    .font(.title2)
                    .bold()

                Text(
                    """
                    TriageU es una aplicación orientada a estudiantes universitarios. Permite registrar actividades académicas y organizarlas teniendo en cuenta la materia, la fecha, el peso en la nota, el nivel de preparación y el tiempo estimado.
                    """
                )

                Text("Tecnologías")
                    .font(.title2)
                    .bold()

                Text(
                    """
                    • Swift
                    • SwiftUI
                    • SwiftData
                    • Arquitectura con ViewModel
                    """
                )

                Text("Créditos")
                    .font(.title2)
                    .bold()

                Text(
                    """
                    Aurelio José Muñoz Rios
                    Isabella Plaza Díaz
                    Isabella Perez Hoyos
                    """
                )
            }
            .frame(
                maxWidth: .infinity,
                alignment: .leading
            )
            .padding()
        }
        .navigationTitle(
            "Acerca de TriageU"
        )
        .navigationBarTitleDisplayMode(
            .inline
        )
    }
}


#Preview {

    ContentView()
        .modelContainer(
            for: TriageActivity.self,
            inMemory: true
        )
}
