import Foundation
import SwiftData
import SwiftUI

@Model
final class Subject {
    var id: UUID
    var name: String
    var colorHex: String
    var createdAt: Date
    var updatedAt: Date

    init(id: UUID = UUID(), name: String, colorHex: String) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    func touch() { updatedAt = Date() }

    var color: Color { Color(hex: colorHex) }
}

enum SubjectDefaults {
    /// IDs fijos para que los dispositivos no dupliquen las materias iniciales.
    static let all: [(id: UUID, name: String, colorHex: String)] = [
        (UUID(uuidString: "00000000-0000-0000-0000-0000000000A1")!, "Comunicaciones Móviles", "#4F7A68"),
        (UUID(uuidString: "00000000-0000-0000-0000-0000000000A2")!, "Aplicaciones Móviles", "#3B82F6"),
        (UUID(uuidString: "00000000-0000-0000-0000-0000000000A3")!, "Entornos Inteligentes", "#F59E0B")
    ]

    static let palette = [
        "#4F7A68", "#3B82F6", "#F59E0B", "#EF4444",
        "#8B5CF6", "#EC4899", "#14B8A6", "#64748B"
    ]
}

extension Color {
    init(hex: String) {
        var h = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        if h.count != 6 { h = "4F7A68" }
        var v: UInt64 = 0
        Scanner(string: h).scanHexInt64(&v)
        self.init(
            red: Double((v >> 16) & 0xFF) / 255,
            green: Double((v >> 8) & 0xFF) / 255,
            blue: Double(v & 0xFF) / 255
        )
    }
}
