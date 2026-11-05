import SwiftUI

/// Calendario mensual con las entregas y la carga de horas de cada día.
struct ActivityCalendarView: View {

    let activities: [TriageActivity]
    let subjectColor: (String) -> Color
    let onToggle: (TriageActivity) -> Void
    let onEdit: (TriageActivity) -> Void
    let onDelete: (TriageActivity) -> Void

    /// Horas de estudio por día a partir de las cuales se marca sobrecarga.
    private let overloadHours = 6

    @State private var month: Date = Calendar.current.startOfMonth(for: Date())
    @State private var selected: Date = Calendar.current.startOfDay(for: Date())

    private var cal: Calendar { Calendar.current }

    private func items(on day: Date) -> [TriageActivity] {
        activities
            .filter { cal.isDate($0.dueDate, inSameDayAs: day) }
            .sorted { $0.dueDate < $1.dueDate }
    }

    private func pendingHours(on day: Date) -> Int {
        items(on: day).filter { !$0.completed }.reduce(0) { $0 + $1.durationMin } / 60
    }

    private var days: [Date?] {
        guard let range = cal.range(of: .day, in: .month, for: month) else { return [] }
        let weekday = cal.component(.weekday, from: month)
        let offset = (weekday - cal.firstWeekday + 7) % 7
        let blanks: [Date?] = Array(repeating: nil, count: offset)
        let real: [Date?] = range.compactMap { cal.date(byAdding: .day, value: $0 - 1, to: month) }
        return blanks + real
    }

    private var weekdaySymbols: [String] {
        let symbols = cal.veryShortStandaloneWeekdaySymbols
        let shift = cal.firstWeekday - 1
        return Array(symbols[shift...] + symbols[..<shift])
    }

    private func tint(_ priority: String) -> Color {
        switch priority {
        case "ALTA": return Color(red: 0.75, green: 0.22, blue: 0.2)
        case "MEDIA": return Color(red: 0.85, green: 0.6, blue: 0.1)
        default: return Color(red: 0.45, green: 0.52, blue: 0.62)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {

            HStack {
                Button { shiftMonth(-1) } label: { Image(systemName: "chevron.left") }
                Spacer()
                Text(month.formatted(.dateTime.month(.wide).year()).capitalized)
                    .font(.system(size: 20, weight: .semibold))
                Spacer()
                Button { shiftMonth(1) } label: { Image(systemName: "chevron.right") }
            }
            .foregroundStyle(triageGreenDark)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 6) {
                ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, s in
                    Text(s)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(textSecondary)
                }

                ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                    if let day {
                        dayCell(day)
                    } else {
                        Color.clear.frame(height: 48)
                    }
                }
            }
            .padding(12)
            .background(Color.white)
            .overlay { RoundedRectangle(cornerRadius: 18).stroke(borderGreen) }
            .clipShape(RoundedRectangle(cornerRadius: 18))

            let dayItems = items(on: selected)
            let hours = pendingHours(on: selected)

            HStack {
                Text(selected.formatted(.dateTime.weekday(.wide).day().month(.wide)).capitalized)
                    .font(.system(size: 19, weight: .semibold))
                Spacer()
                if hours > 0 {
                    Text("\(hours) h de carga")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(hours >= overloadHours ? .red : triageGreenDark)
                }
            }

            if hours >= overloadHours {
                Label("Día sobrecargado: considera adelantar trabajo.", systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.red)
            }

            if dayItems.isEmpty {
                Text("Sin entregas este día.")
                    .foregroundStyle(textSecondary)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 14) {
                    ForEach(dayItems) { a in
                        ActivityCard(
                            activity: a,
                            onToggle: { onToggle(a) },
                            subjectColor: subjectColor(a.subject),
                            onEdit: { onEdit(a) },
                            onDelete: { onDelete(a) }
                        )
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func dayCell(_ day: Date) -> some View {
        let dayItems = items(on: day)
        let isSelected = cal.isDate(day, inSameDayAs: selected)
        let isToday = cal.isDateInToday(day)
        let overloaded = pendingHours(on: day) >= overloadHours

        Button { selected = day } label: {
            VStack(spacing: 4) {
                Text("\(cal.component(.day, from: day))")
                    .font(.system(size: 16, weight: isToday ? .bold : .regular))
                    .foregroundStyle(isSelected ? .white : (isToday ? triageGreen : Color.primary))
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(isSelected ? triageGreen : .clear))

                HStack(spacing: 3) {
                    ForEach(Array(dayItems.prefix(3).enumerated()), id: \.offset) { _, a in
                        Circle()
                            .fill(a.completed ? textSecondary.opacity(0.4) : tint(a.priority))
                            .frame(width: 5, height: 5)
                    }
                }
                .frame(height: 6)
            }
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(overloaded ? Color.red.opacity(0.10) : .clear)
            )
        }
        .buttonStyle(.plain)
    }

    private func shiftMonth(_ delta: Int) {
        if let new = cal.date(byAdding: .month, value: delta, to: month) {
            month = cal.startOfMonth(for: new)
        }
    }
}

extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        self.date(from: dateComponents([.year, .month], from: date)) ?? date
    }
}
