import Foundation


enum SupabaseAPIError: LocalizedError {


    case invalidResponse
    case httpError(statusCode: Int, message: String)


    var errorDescription: String? {
        switch self {


        case .invalidResponse:
            return "El servidor devolvió una respuesta inválida."


        case .httpError(let statusCode, let message):
            switch statusCode {
            case 400:
                return "Solicitud incorrecta: \(message)"
            case 401:
                return "La sesión no es válida o ha expirado."
            case 403:
                return "No tienes permisos para realizar esta operación."
            case 404:
                return "No se encontró el recurso solicitado."
            case 409:
                return "Existe un conflicto con los datos enviados."
            case 500...599:
                return "Error interno del servidor (\(statusCode))."
            default:
                return "Error del servidor (\(statusCode)): \(message)"
            }
        }
    }
}
