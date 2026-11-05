import Foundation

enum SupabaseConfig {
    // Reemplaza con los valores de tu proyecto (Project Settings > API).
    static let url = URL(string: "https://ynetbxihgoziqgspxazx.supabase.co")!
    static let anonKey = "sb_publishable_PEmuiomgdIzxW00QgU87eA_Nky1b4ZG"

    static var isConfigured: Bool {
        !url.absoluteString.contains("TU-PROYECTO") && anonKey != "TU_ANON_KEY"
    }
}
