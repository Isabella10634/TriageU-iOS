import WidgetKit
import SwiftUI

// MARK: - Datos compartidos con la app (App Group)

private let groupId = "group.edu.unicauca.aplimovil.TriageU"
private let storageKey = "widgetItems"

struct WidgetItem: Codable, Identifiable {
    var id: UUID
    var title: String
    var subject: String
    var colorHex: String
    var dueDate: Date
    var hasDueTime: Bool
    var priority: String
}

private func loadItems() -> [WidgetItem] {
    guard let data = UserDefaults(suiteName: groupId)?.data(forKey: storageKey),
          let items = try? JSONDecoder().decode([WidgetItem].self, from: data) else { return [] }
    return items
}

private extension Color {
    init(hex: String) {
        let h = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var v: UInt64 = 0
        Scanner(string: h.count == 6 ? h : "4F7A68").scanHexInt64(&v)
        self.init(
            red: Double((v >> 16) & 0xFF) / 255,
            green: Double((v >> 8) & 0xFF) / 255,
            blue: Double(v & 0xFF) / 255
        )
    }
}

// MARK: - Timeline

struct TriageEntry: TimelineEntry {
    let date: Date
    let items: [WidgetItem]
}

struct Provider: TimelineProvider {

    func placeholder(in context: Context) -> TriageEntry {
        TriageEntry(date: .now, items: [
            WidgetItem(id: UUID(), title: "Parcial 1", subject: "Aplicaciones Móviles",
                       colorHex: "#3B82F6", dueDate: .now.addingTimeInterval(86400),
                       hasDueTime: false, priority: "ALTA")
        ])
    }

    func getSnapshot(in context: Context, completion: @escaping (TriageEntry) -> Void) {
        completion(TriageEntry(date: .now, items: loadItems()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TriageEntry>) -> Void) {
        let entry = TriageEntry(date: .now, items: loadItems())
        let next = Calendar.current.date(byAdding: .minute, value: 30, to: .now) ?? .now
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

// MARK: - Vistas

private struct ItemRow: View {
    let item: WidgetItem
    var showSubject = true

    private var priorityColor: Color {
        switch item.priority {
        case "ALTA": return .red
        case "MEDIA": return .orange
        default: return .gray
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color(hex: item.colorHex))
                .frame(width: 4)
            VStack(alignment: .leading, spacing: 1) {
                Text(item.title)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)
                HStack(spacing: 4) {
                    if showSubject {
                        Text(item.subject).lineLimit(1)
                        Text("·")
                    }
                    Text(item.dueDate, style: .date)
                    if item.hasDueTime { Text(item.dueDate, style: .time) }
                }
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Circle().fill(priorityColor).frame(width: 8, height: 8)
        }
        .frame(height: 34)
    }
}

struct TriageWidgetView: View {

    @Environment(\.widgetFamily) private var family
    let entry: TriageEntry

    var body: some View {
        let limit = family == .systemSmall ? 2 : 3

        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "checklist")
                Text("TriageU").fontWeight(.bold)
                Spacer()
                if !entry.items.isEmpty {
                    Text("\(entry.items.count)")
                        .font(.system(size: 12, weight: .semibold))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(Color(hex: "#4F7A68").opacity(0.18))
                        .clipShape(Capsule())
                }
            }
            .font(.system(size: 13))
            .foregroundStyle(Color(hex: "#3F6B59"))

            if entry.items.isEmpty {
                Spacer()
                Text("Sin actividades pendientes")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                Spacer()
            } else {
                ForEach(entry.items.prefix(limit)) { item in
                    ItemRow(item: item, showSubject: family != .systemSmall)
                }
                Spacer(minLength: 0)
            }
        }
    }
}

struct TriageUWidget: Widget {

    let kind = "TriageUWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            TriageWidgetView(entry: entry)
                .containerBackground(Color(hex: "#F8FBF9"), for: .widget)
        }
        .configurationDisplayName("Próximas entregas")
        .description("Tus actividades pendientes más urgentes.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct TriageUWidgetBundle: WidgetBundle {
    var body: some Widget {
        TriageUWidget()
    }
}
