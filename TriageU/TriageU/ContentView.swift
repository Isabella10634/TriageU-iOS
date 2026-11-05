import SwiftUI
import SwiftData
//commit example 2
// MARK: - COLORES TRIAGEU

private let triageGreen = Color(
    red: 79.0 / 255.0,
    green: 122.0 / 255.0,
    blue: 104.0 / 255.0
)

private let triageGreenDark = Color(
    red: 63.0 / 255.0,
    green: 107.0 / 255.0,
    blue: 89.0 / 255.0
)

private let softGreen = Color(
    red: 234.0 / 255.0,
    green: 244.0 / 255.0,
    blue: 238.0 / 255.0
)

private let backgroundGreen = Color(
    red: 248.0 / 255.0,
    green: 251.0 / 255.0,
    blue: 249.0 / 255.0
)

private let borderGreen = Color(
    red: 221.0 / 255.0,
    green: 229.0 / 255.0,
    blue: 224.0 / 255.0
)

private let textSecondary = Color(
    red: 102.0 / 255.0,
    green: 112.0 / 255.0,
    blue: 133.0 / 255.0
)


// MARK: - CONTENT VIEW PRINCIPAL

struct ContentView: View {

    @State private var viewModel = TriageViewModel()

    @State private var selectedTab: Int = 0

    @State private var showAbout: Bool = false

    var body: some View {

        if showAbout {

            AboutView(
                onBack: {
                    showAbout = false
                }
            )

        } else {

            ZStack(alignment: .bottom) {

                backgroundGreen
                    .ignoresSafeArea()

                Group {

                    switch selectedTab {

                    case 0:
                        TodayView()

                    case 1:
                        RouteView()

                    case 2:
                        NewActivityView(
                            viewModel: viewModel
                        )

                    case 3:
                        TriageProgressView()

                    case 4:
                        ProfileView(
                            onAboutTap: {
                                showAbout = true
                            }
                        )

                    default:
                        TodayView()
                    }
                }
                .padding(.bottom, 78)

                CustomBottomBar(
                    selectedTab: $selectedTab
                )
            }
            .ignoresSafeArea(
                edges: .bottom
            )
        }
    }
}


// MARK: - BARRA DE NAVEGACIÓN INFERIOR

struct CustomBottomBar: View {

    @Binding var selectedTab: Int

    var body: some View {

        ZStack(alignment: .bottom) {

            HStack(spacing: 0) {

                BottomBarItem(
                    title: "Hoy",
                    icon: "house.fill",
                    selected: selectedTab == 0
                ) {
                    selectedTab = 0
                }

                BottomBarItem(
                    title: "Mi Ruta",
                    icon: "point.topleft.down.to.point.bottomright.curvepath",
                    selected: selectedTab == 1
                ) {
                    selectedTab = 1
                }

                Spacer()
                    .frame(width: 78)

                BottomBarItem(
                    title: "Progreso",
                    icon: "chart.line.uptrend.xyaxis",
                    selected: selectedTab == 3
                ) {
                    selectedTab = 3
                }

                BottomBarItem(
                    title: "Perfil",
                    icon: "person.fill",
                    selected: selectedTab == 4
                ) {
                    selectedTab = 4
                }
            }
            .padding(.horizontal, 8)
            .padding(.top, 13)
            .padding(.bottom, 24)
            .background(Color.white)
            .shadow(
                color: Color.black.opacity(0.08),
                radius: 10,
                y: -4
            )

            Button {

                selectedTab = 2

            } label: {

                Image(systemName: "plus")
                    .font(
                        .system(
                            size: 30,
                            weight: .medium
                        )
                    )
                    .foregroundStyle(.white)
                    .frame(
                        width: 72,
                        height: 72
                    )
                    .background(triageGreen)
                    .clipShape(Circle())
                    .shadow(
                        color: Color.black.opacity(0.20),
                        radius: 8,
                        y: 4
                    )
            }
            .offset(y: -42)
        }
    }
}


struct BottomBarItem: View {

    let title: String
    let icon: String
    let selected: Bool
    let action: () -> Void

    var body: some View {

        Button(action: action) {

            VStack(spacing: 5) {

                Image(systemName: icon)
                    .font(
                        .system(
                            size: 22,
                            weight: .medium
                        )
                    )

                Text(title)
                    .font(.caption)
            }
            .foregroundStyle(
                selected
                ? triageGreen
                : textSecondary
            )
            .frame(
                maxWidth: .infinity
            )
        }
        .buttonStyle(.plain)
    }
}


// MARK: - PANTALLA HOY

struct TodayView: View {

    @Environment(\.modelContext)
    private var modelContext

    @Query(
        sort: \TriageActivity.createdAt,
        order: .reverse
    )
    private var activities: [TriageActivity]

    private var pendingActivities: Int {

        activities.filter {
            !$0.completed
        }.count
    }

    var body: some View {

        ScrollView {

            VStack(
                alignment: .leading,
                spacing: 22
            ) {

                VStack(
                    alignment: .leading,
                    spacing: 5
                ) {

                    Text("¡Buenos días!")
                        .font(
                            .system(
                                size: 34,
                                weight: .bold
                            )
                        )

                    Text(
                        Date.now.formatted(
                            .dateTime
                                .weekday(.wide)
                                .day()
                                .month(.wide)
                        )
                    )
                    .font(.system(size: 17))
                    .foregroundStyle(textSecondary)
                }

                VStack(
                    alignment: .leading,
                    spacing: 6
                ) {

                    Text("Hoy tienes:")
                        .font(.headline)
                        .foregroundStyle(
                            triageGreenDark
                        )

                    Text(
                        "\(pendingActivities) actividades pendientes"
                    )
                    .font(.system(size: 19))

                    if !activities.isEmpty {

                        Text(
                            "\(activities.count) actividades registradas"
                        )
                        .font(.system(size: 17))
                        .foregroundStyle(
                            textSecondary
                        )
                    }
                }
                .frame(
                    maxWidth: .infinity,
                    alignment: .leading
                )
                .padding(18)
                .background(softGreen)
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: 18
                    )
                )

                Text("Tu plan recomendado")
                    .font(
                        .system(
                            size: 25,
                            weight: .bold
                        )
                    )

                if activities.isEmpty {

                    EmptyActivitiesView()

                } else {

                    VStack(spacing: 16) {

                        ForEach(
                            activities
                        ) { activity in

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
            }
            .padding(.horizontal, 20)
            .padding(.top, 30)
            .padding(.bottom, 30)
        }
        .background(backgroundGreen)
    }
}


// MARK: - ESTADO VACÍO

struct EmptyActivitiesView: View {

    var body: some View {

        VStack(spacing: 14) {

            Image(
                systemName: "checklist"
            )
            .font(
                .system(size: 42)
            )
            .foregroundStyle(
                triageGreen
            )

            Text(
                "Todavía no tienes actividades."
            )
            .font(.headline)

            Text(
                "Agrégalas usando el botón +."
            )
            .foregroundStyle(
                textSecondary
            )
        }
        .frame(
            maxWidth: .infinity
        )
        .padding(.vertical, 45)
    }
}


// MARK: - TARJETA DE ACTIVIDAD

struct ActivityCard: View {

    let activity: TriageActivity

    let onToggle: () -> Void

    private var priorityColor: Color {

        switch activity.priority {

        case "ALTA":
            return Color(
                red: 159 / 255,
                green: 58 / 255,
                blue: 56 / 255
            )

        case "MEDIA":
            return Color(
                red: 138 / 255,
                green: 90 / 255,
                blue: 0
            )

        default:
            return Color(
                red: 71 / 255,
                green: 85 / 255,
                blue: 105 / 255
            )
        }
    }

    private var priorityBackground: Color {

        switch activity.priority {

        case "ALTA":
            return Color(
                red: 253 / 255,
                green: 237 / 255,
                blue: 236 / 255
            )

        case "MEDIA":
            return Color(
                red: 1.0,
                green: 244 / 255,
                blue: 214 / 255
            )

        default:
            return Color(
                red: 241 / 255,
                green: 245 / 255,
                blue: 249 / 255
            )
        }
    }

    var body: some View {

        HStack(
            alignment: .top,
            spacing: 14
        ) {

            VStack(
                alignment: .leading,
                spacing: 9
            ) {

                Text(
                    "PRIORIDAD \(activity.priority)"
                )
                .font(
                    .system(
                        size: 12,
                        weight: .semibold
                    )
                )
                .foregroundStyle(
                    priorityColor
                )
                .padding(
                    .horizontal,
                    10
                )
                .padding(
                    .vertical,
                    6
                )
                .background(
                    priorityBackground
                )
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: 8
                    )
                )

                Text(activity.title)
                    .font(
                        .system(
                            size: 22,
                            weight: .semibold
                        )
                    )

                Text(
                    "\(activity.durationMin) min recomendados"
                )
                .font(.system(size: 16))
                .foregroundStyle(
                    triageGreen
                )

                HStack(spacing: 5) {

                    Text(
                        activity.dueDate,
                        style: .date
                    )

                    if let weight =
                        activity.weightPercent {

                        Text("·")

                        Text(
                            "\(weight) % de la nota"
                        )
                    }
                }
                .font(.system(size: 15))
                .foregroundStyle(
                    textSecondary
                )

                Text(
                    "Preparación: \(activity.preparation)/5"
                )
                .font(.system(size: 15))
                .foregroundStyle(
                    textSecondary
                )
            }

            Spacer()

            Button(
                action: onToggle
            ) {

                Image(
                    systemName:
                        activity.completed
                        ? "checkmark.circle.fill"
                        : "circle"
                )
                .font(
                    .system(size: 31)
                )
                .foregroundStyle(
                    activity.completed
                    ? triageGreen
                    : textSecondary
                )
            }
            .buttonStyle(.plain)
        }
        .padding(18)
        .background(Color.white)
        .overlay {

            RoundedRectangle(
                cornerRadius: 18
            )
            .stroke(
                borderGreen,
                lineWidth: 1
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

    @Bindable var viewModel:
        TriageViewModel

    var body: some View {

        ScrollView {

            VStack(
                alignment: .leading,
                spacing: 24
            ) {

                Text("Nueva actividad")
                    .font(
                        .system(
                            size: 34,
                            weight: .bold
                        )
                    )

                Text("Información básica")
                    .font(
                        .system(
                            size: 22,
                            weight: .semibold
                        )
                    )

                VStack(spacing: 14) {

                    InputTitle(
                        text: "Materia"
                    )

                    Menu {

                        ForEach(
                            viewModel.subjects,
                            id: \.self
                        ) { subject in

                            Button(subject) {

                                viewModel
                                    .newActivitySubject =
                                    subject
                            }
                        }

                    } label: {

                        SelectionBox(
                            text:
                                viewModel
                                .newActivitySubject
                        )
                    }

                    InputTitle(
                        text: "Actividad"
                    )

                    TextField(
                        "Ej. Parcial 1",
                        text:
                            $viewModel
                            .newActivityTitle
                    )
                    .padding(16)
                    .background(Color.white)
                    .overlay {

                        RoundedRectangle(
                            cornerRadius: 15
                        )
                        .stroke(
                            borderGreen,
                            lineWidth: 1.5
                        )
                    }

                    InputTitle(
                        text: "Tipo"
                    )

                    Menu {

                        ForEach(
                            viewModel.activityTypes,
                            id: \.self
                        ) { type in

                            Button(type) {

                                viewModel
                                    .newActivityType =
                                    type
                            }
                        }

                    } label: {

                        SelectionBox(
                            text:
                                viewModel
                                .newActivityType
                        )
                    }

                    InputTitle(
                        text: "Fecha"
                    )

                    DatePicker(
                        "",
                        selection:
                            $viewModel
                            .newActivityDate,
                        displayedComponents:
                            .date
                    )
                    .labelsHidden()
                    .frame(
                        maxWidth: .infinity,
                        alignment: .leading
                    )
                    .padding(12)
                    .background(Color.white)
                    .overlay {

                        RoundedRectangle(
                            cornerRadius: 15
                        )
                        .stroke(
                            borderGreen,
                            lineWidth: 1.5
                        )
                    }
                }

                Text(
                    "Ayúdanos a priorizarla"
                )
                .font(
                    .system(
                        size: 22,
                        weight: .semibold
                    )
                )

                VStack(
                    alignment: .leading,
                    spacing: 16
                ) {

                    InputTitle(
                        text:
                            "Peso en la materia (Opcional)"
                    )

                    HStack {

                        TextField(
                            "Ej. 30",
                            text:
                                $viewModel
                                .newActivityWeight
                        )
                        .keyboardType(
                            .numberPad
                        )

                        Text("%")
                            .foregroundStyle(
                                textSecondary
                            )
                    }
                    .padding(16)
                    .background(Color.white)
                    .overlay {

                        RoundedRectangle(
                            cornerRadius: 15
                        )
                        .stroke(
                            borderGreen,
                            lineWidth: 1.5
                        )
                    }

                    Text(
                        "¿Qué tan preparado/a te sientes?"
                    )
                    .font(.system(size: 17))

                    PreparationSelector(
                        value:
                            $viewModel
                            .newActivityPreparation
                    )

                    InputTitle(
                        text:
                            "Tiempo estimado"
                    )

                    HStack {

                        Button {

                            if viewModel
                                .newActivityEstimatedHours
                                > 1 {

                                viewModel
                                    .newActivityEstimatedHours
                                    -= 1
                            }

                        } label: {

                            Image(
                                systemName: "minus"
                            )
                            .font(.title3)
                        }

                        Spacer()

                        Text(
                            "\(viewModel.newActivityEstimatedHours) horas"
                        )
                        .font(.system(size: 18))

                        Spacer()

                        Button {

                            if viewModel
                                .newActivityEstimatedHours
                                < 12 {

                                viewModel
                                    .newActivityEstimatedHours
                                    += 1
                            }

                        } label: {

                            Image(
                                systemName: "plus"
                            )
                            .font(.title3)
                        }
                    }
                    .foregroundStyle(
                        triageGreenDark
                    )
                    .padding(16)
                    .background(Color.white)
                    .overlay {

                        RoundedRectangle(
                            cornerRadius: 15
                        )
                        .stroke(
                            borderGreen,
                            lineWidth: 1.5
                        )
                    }
                }

                Button {

                    viewModel.saveActivity(
                        context: modelContext
                    )

                } label: {

                    Text(
                        "Guardar actividad"
                    )
                    .font(
                        .system(
                            size: 18,
                            weight: .semibold
                        )
                    )
                    .foregroundStyle(.white)
                    .frame(
                        maxWidth: .infinity
                    )
                    .padding(.vertical, 17)
                    .background(
                        triageGreen
                    )
                    .clipShape(
                        RoundedRectangle(
                            cornerRadius: 15
                        )
                    )
                }
                .buttonStyle(.plain)

                if let message =
                    viewModel.lastMessage {

                    Text(message)
                        .font(.system(size: 14))
                        .foregroundStyle(
                            textSecondary
                        )
                        .frame(
                            maxWidth: .infinity,
                            alignment: .center
                        )
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 30)
            .padding(.bottom, 40)
        }
        .background(backgroundGreen)
    }
}


struct InputTitle: View {

    let text: String

    var body: some View {

        Text(text)
            .font(.system(size: 17))
            .foregroundStyle(
                Color.primary
            )
            .frame(
                maxWidth: .infinity,
                alignment: .leading
            )
    }
}


struct SelectionBox: View {

    let text: String

    var body: some View {

        HStack {

            Text(text)
                .foregroundStyle(
                    Color.primary
                )

            Spacer()

            Image(
                systemName:
                    "chevron.down"
            )
            .foregroundStyle(
                textSecondary
            )
        }
        .font(.system(size: 17))
        .padding(16)
        .background(Color.white)
        .overlay {

            RoundedRectangle(
                cornerRadius: 15
            )
            .stroke(
                borderGreen,
                lineWidth: 1.5
            )
        }
    }
}


// MARK: - SELECTOR PREPARACIÓN

struct PreparationSelector: View {

    @Binding var value: Int

    var body: some View {

        HStack(spacing: 10) {

            Text("Muy\npoco")
                .font(.caption)
                .foregroundStyle(
                    textSecondary
                )

            ForEach(
                1...5,
                id: \.self
            ) { number in

                Button {

                    value = number

                } label: {

                    Text("\(number)")
                        .font(
                            .system(
                                size: 16,
                                weight: .medium
                            )
                        )
                        .foregroundStyle(
                            value == number
                            ? triageGreenDark
                            : Color.primary
                        )
                        .frame(
                            width: 43,
                            height: 43
                        )
                        .background(
                            value == number
                            ? softGreen
                            : Color.white
                        )
                        .clipShape(Circle())
                        .overlay {

                            Circle()
                                .stroke(
                                    value == number
                                    ? triageGreen
                                    : borderGreen,
                                    lineWidth:
                                        value == number
                                        ? 2
                                        : 1
                                )
                        }
                }
                .buttonStyle(.plain)
            }

            Text("Muy\nbien")
                .font(.caption)
                .foregroundStyle(
                    textSecondary
                )
        }
        .frame(
            maxWidth: .infinity
        )
    }
}


// MARK: - MI RUTA

struct RouteView: View {

    @Query(
        sort:
            \TriageActivity.dueDate
    )
    private var activities:
        [TriageActivity]

    var body: some View {

        ScrollView {

            VStack(
                alignment: .leading,
                spacing: 20
            ) {

                Text("Mi ruta")
                    .font(
                        .system(
                            size: 34,
                            weight: .bold
                        )
                    )

                Text("Próximos días")
                    .font(.system(size: 18))
                    .foregroundStyle(
                        textSecondary
                    )

                if activities.isEmpty {

                    VStack(
                        alignment: .leading,
                        spacing: 12
                    ) {

                        Text(
                            "Aún no tienes una ruta."
                        )
                        .font(.headline)

                        Text(
                            "Agrega actividades para construir tu planificación."
                        )
                        .foregroundStyle(
                            textSecondary
                        )
                    }
                    .padding(.top, 30)

                } else {

                    VStack(
                        spacing: 0
                    ) {

                        ForEach(
                            activities
                        ) { activity in

                            RouteItem(
                                activity:
                                    activity
                            )
                        }
                    }
                }
            }
            .frame(
                maxWidth: .infinity,
                alignment: .leading
            )
            .padding(.horizontal, 20)
            .padding(.top, 30)
            .padding(.bottom, 40)
        }
        .background(backgroundGreen)
    }
}


struct RouteItem: View {

    let activity: TriageActivity

    var body: some View {

        HStack(
            alignment: .top,
            spacing: 16
        ) {

            VStack(spacing: 0) {

                Circle()
                    .fill(triageGreen)
                    .frame(
                        width: 20,
                        height: 20
                    )

                Rectangle()
                    .fill(borderGreen)
                    .frame(
                        width: 3,
                        height: 90
                    )
            }

            VStack(
                alignment: .leading,
                spacing: 6
            ) {

                Text(
                    activity.dueDate,
                    style: .date
                )
                .font(.caption)
                .foregroundStyle(
                    triageGreenDark
                )

                Text(activity.title)
                    .font(
                        .system(
                            size: 21,
                            weight: .semibold
                        )
                    )

                Text(activity.subject)
                    .foregroundStyle(
                        textSecondary
                    )

                Text(
                    activity.type
                )
                .font(.caption)
                .foregroundStyle(
                    textSecondary
                )
            }

            Spacer()
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

        ScrollView {

            VStack(
                alignment: .leading,
                spacing: 25
            ) {

                Text("Mi progreso")
                    .font(
                        .system(
                            size: 34,
                            weight: .bold
                        )
                    )

                Text("Avanza a tu ritmo")
                    .font(.system(size: 18))
                    .foregroundStyle(
                        textSecondary
                    )

                Text("ESTA SEMANA")
                    .font(
                        .system(
                            size: 15,
                            weight: .semibold
                        )
                    )

                HStack {

                    Text(
                        "\(completed) de \(activities.count) actividades realizadas"
                    )
                    .font(.system(size: 17))

                    Spacer()

                    Text(
                        "\(Int(progress * 100)) %"
                    )
                    .font(
                        .system(
                            size: 21,
                            weight: .bold
                        )
                    )
                    .foregroundStyle(
                        triageGreen
                    )
                }

                ProgressView(
                    value: progress
                )
                .tint(triageGreen)
                .scaleEffect(
                    x: 1,
                    y: 2,
                    anchor: .center
                )

                VStack(
                    alignment: .leading,
                    spacing: 10
                ) {

                    Text(
                        "\(activities.count) actividades registradas"
                    )
                    .font(.system(size: 19))

                    Text(
                        "\(activities.count - completed) pendientes"
                    )
                    .font(.system(size: 19))
                }

                VStack(
                    alignment: .leading,
                    spacing: 8
                ) {

                    Text("Buen avance")
                        .font(
                            .system(
                                size: 20,
                                weight: .semibold
                            )
                        )

                    Text(
                        "Continúa organizando tus actividades y completando tus pendientes."
                    )
                    .foregroundStyle(
                        textSecondary
                    )
                }
                .frame(
                    maxWidth: .infinity,
                    alignment: .leading
                )
                .padding(18)
                .background(Color.white)
                .overlay {

                    RoundedRectangle(
                        cornerRadius: 18
                    )
                    .stroke(
                        borderGreen,
                        lineWidth: 1
                    )
                }
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: 18
                    )
                )
            }
            .padding(.horizontal, 20)
            .padding(.top, 30)
        }
        .background(backgroundGreen)
    }
}


// MARK: - PERFIL

struct ProfileView: View {

    let onAboutTap: () -> Void

    var body: some View {

        ScrollView {

            VStack(spacing: 25) {

                Text("Perfil")
                    .font(
                        .system(
                            size: 34,
                            weight: .bold
                        )
                    )
                    .frame(
                        maxWidth: .infinity,
                        alignment: .leading
                    )

                ZStack {

                    Circle()
                        .fill(softGreen)
                        .frame(
                            width: 120,
                            height: 120
                        )

                    Image(
                        systemName:
                            "person.fill"
                    )
                    .font(
                        .system(size: 52)
                    )
                    .foregroundStyle(
                        triageGreen
                    )
                }

                VStack(spacing: 5) {

                    Text(
                        "Estudiante TriageU"
                    )
                    .font(
                        .system(
                            size: 25,
                            weight: .semibold
                        )
                    )

                    Text(
                        "Prioriza tu tiempo. Avanza a tu ritmo."
                    )
                    .foregroundStyle(
                        textSecondary
                    )
                }

                VStack(
                    alignment: .leading,
                    spacing: 13
                ) {

                    Text("Mis materias")
                        .font(
                            .system(
                                size: 20,
                                weight: .semibold
                            )
                        )
                        .foregroundStyle(
                            textSecondary
                        )

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
                .font(.system(size: 18))
                .frame(
                    maxWidth: .infinity,
                    alignment: .leading
                )
                .padding(20)
                .background(Color.white)
                .overlay {

                    RoundedRectangle(
                        cornerRadius: 18
                    )
                    .stroke(
                        borderGreen
                    )
                }
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: 18
                    )
                )

                Button(
                    action: onAboutTap
                ) {

                    HStack(spacing: 15) {

                        ZStack {

                            Circle()
                                .fill(
                                    softGreen
                                )
                                .frame(
                                    width: 48,
                                    height: 48
                                )

                            Image(
                                systemName:
                                    "info.circle.fill"
                            )
                            .foregroundStyle(
                                triageGreen
                            )
                        }

                        VStack(
                            alignment: .leading,
                            spacing: 4
                        ) {

                            Text(
                                "Acerca de TriageU"
                            )
                            .font(
                                .system(
                                    size: 18,
                                    weight: .semibold
                                )
                            )
                            .foregroundStyle(
                                Color.primary
                            )

                            Text(
                                "Descripción de la aplicación y créditos"
                            )
                            .font(.caption)
                            .foregroundStyle(
                                textSecondary
                            )
                        }

                        Spacer()

                        Image(
                            systemName:
                                "chevron.right"
                        )
                        .foregroundStyle(
                            textSecondary
                        )
                    }
                    .padding(18)
                    .background(Color.white)
                    .overlay {

                        RoundedRectangle(
                            cornerRadius: 18
                        )
                        .stroke(
                            borderGreen
                        )
                    }
                    .clipShape(
                        RoundedRectangle(
                            cornerRadius: 18
                        )
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.top, 30)
        }
        .background(backgroundGreen)
    }
}


// MARK: - ACERCA DE

struct AboutView: View {

    let onBack: () -> Void

    var body: some View {

        ZStack {

            backgroundGreen
                .ignoresSafeArea()

            ScrollView {

                VStack(
                    alignment: .leading,
                    spacing: 24
                ) {

                    HStack {

                        Button(
                            action: onBack
                        ) {

                            Image(
                                systemName:
                                    "arrow.left"
                            )
                            .font(
                                .system(
                                    size: 21,
                                    weight: .medium
                                )
                            )
                            .foregroundStyle(
                                Color.primary
                            )
                        }

                        Text(
                            "Acerca de TriageU"
                        )
                        .font(
                            .system(
                                size: 24,
                                weight: .bold
                            )
                        )

                        Spacer()
                    }

                    VStack(
                        alignment: .leading,
                        spacing: 6
                    ) {

                        Text("TriageU")
                            .font(
                                .system(
                                    size: 34,
                                    weight: .bold
                                )
                            )
                            .foregroundStyle(
                                triageGreen
                            )

                        Text(
                            "Prioriza tu tiempo. Avanza a tu ritmo."
                        )
                        .foregroundStyle(
                            textSecondary
                        )
                    }

                    AboutCard(
                        title:
                            "¿Qué es TriageU?",
                        text:
                            """
                            TriageU es una aplicación orientada a estudiantes universitarios. Permite registrar actividades académicas y organizarlas teniendo en cuenta la materia, la fecha, el peso en la nota, el nivel de preparación y el tiempo estimado.
                            """
                    )

                    AboutCard(
                        title:
                            "Funcionamiento",
                        text:
                            """
                            El estudiante registra sus actividades académicas y TriageU calcula una prioridad según la preparación y el peso de la actividad. Las actividades se almacenan localmente para conservar la información.
                            """
                    )

                    AboutCard(
                        title:
                            "Tecnologías utilizadas",
                        text:
                            """
                            • Swift
                            • SwiftUI
                            • SwiftData
                            • ViewModel con @Observable
                            """
                    )

                    AboutCard(
                        title: "Créditos",
                        text:
                            """
                            Aurelio José Muñoz Rios
                            Isabella Plaza Díaz
                            Isabella Perez Hoyos
                            """
                    )

                    Text(
                        "TriageU · Desarrollo de Aplicaciones Móviles"
                    )
                    .font(.caption)
                    .foregroundStyle(
                        textSecondary
                    )
                    .frame(
                        maxWidth: .infinity,
                        alignment: .center
                    )
                    .padding(.top, 10)
                }
                .padding(.horizontal, 20)
                .padding(.top, 25)
                .padding(.bottom, 35)
            }
        }
    }
}


struct AboutCard: View {

    let title: String
    let text: String

    var body: some View {

        VStack(
            alignment: .leading,
            spacing: 10
        ) {

            Text(title)
                .font(
                    .system(
                        size: 20,
                        weight: .semibold
                    )
                )

            Text(text)
                .font(.system(size: 16))
                .foregroundStyle(
                    textSecondary
                )
        }
        .frame(
            maxWidth: .infinity,
            alignment: .leading
        )
        .padding(18)
        .background(Color.white)
        .overlay {

            RoundedRectangle(
                cornerRadius: 18
            )
            .stroke(
                borderGreen,
                lineWidth: 1
            )
        }
        .clipShape(
            RoundedRectangle(
                cornerRadius: 18
            )
        )
    }
}


// MARK: - PREVIEW

#Preview {

    ContentView()
        .modelContainer(
            for:
                TriageActivity.self,
            inMemory: true
        )
}
