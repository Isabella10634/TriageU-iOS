import SwiftUI

struct AuthView: View {

    private let auth = AuthManager.shared

    @State private var email = ""
    @State private var password = ""
    @State private var isRegistering = false

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {

                Image(systemName: "checklist")
                    .font(.system(size: 54))
                    .foregroundStyle(triageGreen)
                    .padding(.top, 60)

                Text("TriageU")
                    .font(.system(size: 34, weight: .bold))

                Text(isRegistering ? "Crea tu cuenta" : "Inicia sesión para sincronizar tus actividades")
                    .foregroundStyle(textSecondary)
                    .multilineTextAlignment(.center)

                VStack(spacing: 14) {
                    TextField("Correo", text: $email)
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .padding(16)
                        .background(Color.white)
                        .overlay { RoundedRectangle(cornerRadius: 15).stroke(borderGreen, lineWidth: 1.5) }

                    SecureField("Contraseña (mín. 6 caracteres)", text: $password)
                        .textContentType(isRegistering ? .newPassword : .password)
                        .padding(16)
                        .background(Color.white)
                        .overlay { RoundedRectangle(cornerRadius: 15).stroke(borderGreen, lineWidth: 1.5) }
                }

                if let error = auth.errorMessage {
                    Text(error)
                        .font(.system(size: 14))
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }
                if let info = auth.infoMessage {
                    Text(info)
                        .font(.system(size: 14))
                        .foregroundStyle(triageGreenDark)
                        .multilineTextAlignment(.center)
                }

                Button {
                    Task {
                        if isRegistering {
                            await auth.signUp(email: email, password: password)
                        } else {
                            await auth.signIn(email: email, password: password)
                        }
                    }
                } label: {
                    Group {
                        if auth.isLoading {
                            ProgressView().tint(.white)
                        } else {
                            Text(isRegistering ? "Crear cuenta" : "Iniciar sesión")
                                .font(.system(size: 18, weight: .semibold))
                        }
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 17)
                    .background(triageGreen)
                    .clipShape(RoundedRectangle(cornerRadius: 15))
                }
                .buttonStyle(.plain)
                .disabled(auth.isLoading)

                Button {
                    isRegistering.toggle()
                    auth.errorMessage = nil
                    auth.infoMessage = nil
                } label: {
                    Text(isRegistering ? "¿Ya tienes cuenta? Inicia sesión" : "¿No tienes cuenta? Regístrate")
                        .font(.system(size: 16))
                        .foregroundStyle(triageGreenDark)
                }
            }
            .padding(.horizontal, 24)
        }
        .background(backgroundGreen.ignoresSafeArea())
    }
}
