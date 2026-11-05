import SwiftUI
import SwiftData
//commit example 2
// MARK: - COLORES TRIAGEU

let triageGreen = Color(
    red: 79.0 / 255.0,
    green: 122.0 / 255.0,
    blue: 104.0 / 255.0
)

let triageGreenDark = Color(
    red: 63.0 / 255.0,
    green: 107.0 / 255.0,
    blue: 89.0 / 255.0
)

let softGreen = Color(
    red: 234.0 / 255.0,
    green: 244.0 / 255.0,
    blue: 238.0 / 255.0
)

let backgroundGreen = Color(
    red: 248.0 / 255.0,
    green: 251.0 / 255.0,
    blue: 249.0 / 255.0
)

let borderGreen = Color(
    red: 221.0 / 255.0,
    green: 229.0 / 255.0,
    blue: 224.0 / 255.0
)

let textSecondary = Color(
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

    @Query(sort: \Subject.name)
    private var subjects: [Subject]

    enum StatusFilter: String, CaseIterable {
        case all = "Todas", pending = "Pendientes", done = "Completadas"
    }

    enum SortMode: String, CaseIterable {
        case dueDate = "Fecha de entrega", priority = "Prioridad", created = "Más recientes"
    }

    enum ViewMode: String, CaseIterable {
        case list = "Lista", calendar = "Calendario"
    }

    @State private var editingActivity: TriageActivity?

    // Deshacer borrado
    @State private var hiddenIds: Set<UUID> = []
    @State private var pendingDeleteId: UUID?
    @State private var undoTask: Task<Void, Never>?

    // Búsqueda y filtros
    @State private var searchText = ""
    @State private var subjectFilter: String?
    @State private var priorityFilter: String?
    @State private var statusFilter: StatusFilter = .all
    @State private var sortMode: SortMode = .dueDate
    @State private var mode: ViewMode = .list

    private var visibleActivities: [TriageActivity] {
        activities.filter { !hiddenIds.contains($0.id) }
    }

    private var pendingActivities: Int {
        visibleActivities.filter { !$0.completed }.count
    }

    private func priorityRank(_ p: String) -> Int {
        switch p { case "ALTA": return 0; case "MEDIA": return 1; default: return 2 }
    }

    private var filteredActivities: [TriageActivity] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let list = visibleActivities.filter { a in
            if let subjectFilter, a.subject != subjectFilter { return false }
            if let priorityFilter, a.priority != priorityFilter { return false }
            switch statusFilter {
            case .all: break
            case .pending: if a.completed { return false }
            case .done: if !a.completed { return false }
            }
            if !query.isEmpty,
               !a.title.localizedCaseInsensitiveContains(query),
               !a.subject.localizedCaseInsensitiveContains(query) { return false }
            return true
        }
        switch sortMode {
        case .dueDate:
            return list.sorted { $0.dueDate < $1.dueDate }
        case .priority:
            return list.sorted {
                priorityRank($0.priority) != priorityRank($1.priority)
                ? priorityRank($0.priority) < priorityRank($1.priority)
                : $0.dueDate < $1.dueDate
            }
        case .created:
            return list.sorted { $0.createdAt > $1.createdAt }
        }
    }

    private var hasActiveFilters: Bool {
        subjectFilter != nil || priorityFilter != nil || statusFilter != .all || !searchText.isEmpty
    }

    private func color(for subject: String) -> Color {
        subjects.first { $0.name == subject }?.color ?? triageGreen
    }

    private func toggle(_ activity: TriageActivity) {
        activity.completed.toggle()
        activity.touch()
        try? modelContext.save()
        Task {
            await SupabaseService.upsert(activity)
            await NotificationService.schedule(for: activity)
        }
    }

    // MARK: Borrado con deshacer

    private func beginDelete(_ activity: TriageActivity) {
        commitPendingDelete()
        pendingDeleteId = activity.id
        hiddenIds.insert(activity.id)
        undoTask = Task {
            try? await Task.sleep(for: .seconds(5))
            if !Task.isCancelled { commitPendingDelete() }
        }
    }

    private func commitPendingDelete() {
        undoTask?.cancel()
        undoTask = nil
        guard let id = pendingDeleteId else { return }
        pendingDeleteId = nil
        if let activity = activities.first(where: { $0.id == id }) {
            NotificationService.cancel(id: id)
            modelContext.delete(activity)
            try? modelContext.save()
            Task { await SupabaseService.delete(id: id) }
        }
        hiddenIds.remove(id)
    }

    private func undoDelete() {
        undoTask?.cancel()
        undoTask = nil
        if let id = pendingDeleteId { hiddenIds.remove(id) }
        pendingDeleteId = nil
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

                    if !visibleActivities.isEmpty {

                        Text(
                            "\(visibleActivities.count) actividades registradas"
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

                if visibleActivities.isEmpty {

                    EmptyActivitiesView()

                } else {

                    filterBar

                    Picker("Vista", selection: $mode) {
                        ForEach(ViewMode.allCases, id: \.self) {
                            Text($0.rawValue).tag($0)
                        }
                    }
                    .pickerStyle(.segmented)

                    if mode == .calendar {

                        ActivityCalendarView(
                            activities: filteredActivities,
                            subjectColor: color(for:),
                            onToggle: toggle,
                            onEdit: { editingActivity = $0 },
                            onDelete: beginDelete
                        )

                    } else if filteredActivities.isEmpty {

                        Text("Ninguna actividad coincide con los filtros.")
                            .foregroundStyle(textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 30)

                    } else {

                        VStack(spacing: 16) {

                            ForEach(
                                filteredActivities
                            ) { activity in

                                ActivityCard(
                                    activity: activity,
                                    onToggle: { toggle(activity) },
                                    subjectColor: color(for: activity.subject),
                                    onEdit: { editingActivity = activity },
                                    onDelete: { beginDelete(activity) }
                                )
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 30)
            .padding(.bottom, 30)
        }
        .background(backgroundGreen)
        .sheet(item: $editingActivity) { activity in
            EditActivityView(activity: activity)
        }
        .overlay(alignment: .bottom) {
            if pendingDeleteId != nil {
                HStack {
                    Text("Actividad eliminada")
                        .foregroundStyle(.white)
                    Spacer()
                    Button("Deshacer") { undoDelete() }
                        .fontWeight(.semibold)
                        .foregroundStyle(Color(hex: "#9FE0C0"))
                }
                .padding(16)
                .background(Color.black.opacity(0.85))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: pendingDeleteId)
        .onDisappear { commitPendingDelete() }
    }

    // MARK: Barra de búsqueda y filtros

    private var filterBar: some View {
        VStack(spacing: 12) {

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(textSecondary)
                TextField("Buscar actividad o materia", text: $searchText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                if !searchText.isEmpty {
                    Button { searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(textSecondary)
                    }
                }
            }
            .padding(12)
            .background(Color.white)
            .overlay { RoundedRectangle(cornerRadius: 12).stroke(borderGreen) }
            .clipShape(RoundedRectangle(cornerRadius: 12))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {

                    Menu {
                        Button("Todas las materias") { subjectFilter = nil }
                        ForEach(subjects) { s in
                            Button(s.name) { subjectFilter = s.name }
                        }
                    } label: {
                        chip(subjectFilter ?? "Materia", active: subjectFilter != nil)
                    }

                    Menu {
                        Button("Toda prioridad") { priorityFilter = nil }
                        ForEach(["ALTA", "MEDIA", "BAJA"], id: \.self) { p in
                            Button(p.capitalized) { priorityFilter = p }
                        }
                    } label: {
                        chip(priorityFilter?.capitalized ?? "Prioridad", active: priorityFilter != nil)
                    }

                    Menu {
                        ForEach(StatusFilter.allCases, id: \.self) { f in
                            Button(f.rawValue) { statusFilter = f }
                        }
                    } label: {
                        chip(statusFilter.rawValue, active: statusFilter != .all)
                    }

                    if mode == .list {
                        Menu {
                            ForEach(SortMode.allCases, id: \.self) { m in
                                Button(m.rawValue) { sortMode = m }
                            }
                        } label: {
                            chip("Orden: \(sortMode.rawValue)", active: false, icon: "arrow.up.arrow.down")
                        }
                    }

                    if hasActiveFilters {
                        Button {
                            subjectFilter = nil
                            priorityFilter = nil
                            statusFilter = .all
                            searchText = ""
                        } label: {
                            Text("Limpiar")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.red)
                        }
                    }
                }
            }
        }
    }

    private func chip(_ text: String, active: Bool, icon: String = "chevron.down") -> some View {
        HStack(spacing: 5) {
            Text(text)
            Image(systemName: icon).font(.system(size: 10, weight: .bold))
        }
        .font(.system(size: 14, weight: .medium))
        .foregroundStyle(active ? .white : triageGreenDark)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(active ? triageGreen : softGreen)
        .clipShape(Capsule())
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
    var subjectColor: Color = triageGreen
    var onEdit: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil

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

                HStack(spacing: 6) {
                    Circle()
                        .fill(subjectColor)
                        .frame(width: 9, height: 9)
                    Text(activity.subject)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(textSecondary)
                }

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

                    if activity.hasDueTime {
                        Text("·")
                        Text(
                            activity.dueDate,
                            style: .time
                        )
                    }

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

            VStack(spacing: 18) {

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

                if onEdit != nil || onDelete != nil {

                    Menu {
                        if let onEdit {
                            Button("Editar", systemImage: "pencil", action: onEdit)
                        }
                        if let onDelete {
                            Button("Eliminar", systemImage: "trash", role: .destructive, action: onDelete)
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.system(size: 24))
                            .foregroundStyle(textSecondary)
                    }
                }
            }
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

    @Query(sort: \Subject.name)
    private var subjectList: [Subject]

    private var subjectNames: [String] {
        subjectList.map(\.name)
    }

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
                            subjectNames,
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

                    Toggle(
                        "Definir hora de entrega",
                        isOn: $viewModel.newActivityHasTime
                    )
                    .tint(triageGreen)

                    if viewModel.newActivityHasTime {
                        DatePicker(
                            "",
                            selection: $viewModel.newActivityDate,
                            displayedComponents: .hourAndMinute
                        )
                        .labelsHidden()
                        .frame(maxWidth: .infinity, alignment: .leading)
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
        .onAppear {
            if !subjectNames.contains(viewModel.newActivitySubject) {
                viewModel.newActivitySubject = subjectNames.first ?? ""
            }
        }
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

    private let auth = AuthManager.shared

    @Environment(\.modelContext)
    private var modelContext

    @Query(sort: \Subject.name)
    private var subjects: [Subject]

    @State private var showSubjects = false
    @State private var confirmSignOut = false

    private let queue = SyncQueue.shared

    @AppStorage(NotificationService.hourBeforeKey)
    private var hourBefore: Int = 9

    @AppStorage(NotificationService.hourDayKey)
    private var hourDay: Int = 8

    private func rescheduleReminders() {
        let all = (try? modelContext.fetch(FetchDescriptor<TriageActivity>())) ?? []
        Task { await NotificationService.rescheduleAll(all) }
    }

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
                        auth.session?.email ?? "Estudiante TriageU"
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

                    ForEach(subjects) { subject in
                        HStack(spacing: 10) {
                            Circle()
                                .fill(subject.color)
                                .frame(width: 11, height: 11)
                            Text(subject.name)
                        }
                    }

                    Button {
                        showSubjects = true
                    } label: {
                        Label("Administrar materias", systemImage: "slider.horizontal.3")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(triageGreenDark)
                    }
                    .padding(.top, 4)
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

                VStack(alignment: .leading, spacing: 8) {

                    Text("Recordatorios")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(textSecondary)

                    Stepper(
                        "Día anterior: \(String(format: "%02d", hourBefore)):00",
                        value: $hourBefore,
                        in: 0...23
                    )

                    Stepper(
                        "Día de entrega: \(String(format: "%02d", hourDay)):00",
                        value: $hourDay,
                        in: 0...23
                    )
                }
                .font(.system(size: 17))
                .padding(20)
                .background(Color.white)
                .overlay {
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(borderGreen)
                }
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .onChange(of: hourBefore) { rescheduleReminders() }
                .onChange(of: hourDay) { rescheduleReminders() }

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

                if auth.isSignedIn {

                    if queue.pendingCount > 0 {
                        Label(
                            "\(queue.pendingCount) cambios pendientes de sincronizar",
                            systemImage: "arrow.triangle.2.circlepath"
                        )
                        .font(.system(size: 14))
                        .foregroundStyle(textSecondary)
                    }

                    Button(role: .destructive) {
                        Task {
                            await queue.flush()
                            if queue.pendingCount > 0 {
                                confirmSignOut = true
                            } else {
                                auth.signOut()
                            }
                        }
                    } label: {
                        Text("Cerrar sesión")
                            .font(.system(size: 18, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.white)
                            .overlay {
                                RoundedRectangle(cornerRadius: 15)
                                    .stroke(borderGreen, lineWidth: 1.5)
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 15))
                    }
                    .padding(.bottom, 30)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 30)
        }
        .background(backgroundGreen)
        .sheet(isPresented: $showSubjects) {
            SubjectsView()
        }
        .confirmationDialog(
            "Hay cambios sin sincronizar",
            isPresented: $confirmSignOut,
            titleVisibility: .visible
        ) {
            Button("Cerrar sesión y descartarlos", role: .destructive) {
                queue.clear()
                auth.signOut()
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Sin conexión no se pudieron subir \(queue.pendingCount) cambios. Si cierras sesión ahora se perderán.")
        }
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
