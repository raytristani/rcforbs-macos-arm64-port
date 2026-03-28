import SwiftUI
import LocalAuthentication

struct LoginView: View {
    @EnvironmentObject var connectionManager: ConnectionManager
    @State private var user = ""
    @State private var password = ""
    @State private var remember = false
    @State private var loading = false
    @State private var error = ""
    @State private var biometricsAvailable = false
    @State private var hasSavedCreds = false
    @State private var biometricType: LABiometryType = .none

    var body: some View {
        ZStack {
            Color(hex: "#2a2a2a").ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    Spacer(minLength: 60)
                    loginCard
                    Spacer(minLength: 60)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .onAppear {
            if let creds = CredentialStore.load() {
                user = creds.user
                password = creds.password
                remember = true
                hasSavedCreds = true
            }
            checkBiometrics()
            if hasSavedCreds && biometricsAvailable {
                authenticateWithBiometrics()
            }
        }
    }

    private var loginCard: some View {
        VStack(spacing: 0) {
            Text("RCForb")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(Color.cream)
                .padding(.bottom, 6)

            Text("Remote Ham Radio Control")
                .font(.system(size: 13))
                .foregroundColor(Color.creamDark)
                .padding(.bottom, 24)

            if !error.isEmpty {
                Text(error)
                    .font(.system(size: 13))
                    .foregroundColor(Color(hex: "#fca5a5"))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
                    .background(Color(hex: "#7f1d1d").opacity(0.6))
                    .cornerRadius(4)
                    .padding(.bottom, 16)
            }

            VStack(spacing: 16) {
                // Biometric login button
                if hasSavedCreds && biometricsAvailable {
                    biometricButton
                }

                // Username
                VStack(alignment: .leading, spacing: 4) {
                    Text("Username")
                        .font(.system(size: 13))
                        .foregroundColor(Color.cream)
                    StyledTextField(placeholder: "Your RemoteHams.com username", text: $user, onSubmit: handleLogin)
                        .frame(height: 30)
                        .padding(.horizontal, 12)
                        .background(
                            LinearGradient(colors: [Color(hex: "#666555"), Color(hex: "#555444")], startPoint: .top, endPoint: .bottom)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color.btnBorder, lineWidth: 1)
                        )
                        .cornerRadius(4)
                }

                // Password
                VStack(alignment: .leading, spacing: 4) {
                    Text("Password")
                        .font(.system(size: 13))
                        .foregroundColor(Color.cream)
                    StyledTextField(placeholder: "Password", text: $password, isSecure: true, onSubmit: handleLogin)
                        .frame(height: 30)
                        .padding(.horizontal, 12)
                        .background(
                            LinearGradient(colors: [Color(hex: "#666555"), Color(hex: "#555444")], startPoint: .top, endPoint: .bottom)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color.btnBorder, lineWidth: 1)
                        )
                        .cornerRadius(4)
                }

                // Remember me
                Toggle(isOn: $remember) {
                    Text("Remember me")
                        .font(.system(size: 13))
                        .foregroundColor(Color.creamDark)
                }
                .toggleStyle(.switch)
                .tint(Color.cream)

                // Login button
                Text(loading ? "Logging in..." : "Login")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Color.textDark)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(
                        loading
                        ? AnyView(Color(hex: "#555444"))
                        : AnyView(LinearGradient(colors: [Color.cream, Color.creamDark], startPoint: .top, endPoint: .bottom))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.cream, lineWidth: 2)
                    )
                    .cornerRadius(4)
                    .contentShape(Rectangle())
                    .onTapGesture { handleLogin() }
                    .opacity(loading || user.isEmpty || password.isEmpty ? 0.5 : 1.0)
            }
        }
        .padding(32)
        .frame(maxWidth: 420)
        .background(
            LinearGradient(colors: [Color(hex: "#888666"), Color(hex: "#555444")], startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.btnBorder, lineWidth: 2)
        )
        .cornerRadius(8)
        .shadow(color: .black.opacity(0.5), radius: 20)
    }

    private var biometricButton: some View {
        HStack(spacing: 8) {
            Image(systemName: biometricType == .faceID ? "faceid" : "touchid")
                .font(.system(size: 22))
            Text(biometricType == .faceID ? "Sign in with Face ID" : "Sign in with Touch ID")
                .font(.system(size: 14, weight: .semibold))
        }
        .foregroundColor(Color.cream)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            LinearGradient(colors: [Color(hex: "#445566"), Color(hex: "#334455")], startPoint: .top, endPoint: .bottom)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color(hex: "#667788"), lineWidth: 1)
        )
        .cornerRadius(6)
        .contentShape(Rectangle())
        .onTapGesture { authenticateWithBiometrics() }
    }

    private func checkBiometrics() {
        let context = LAContext()
        var authError: NSError?
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &authError) {
            biometricsAvailable = true
            biometricType = context.biometryType
        }
    }

    private func authenticateWithBiometrics() {
        let context = LAContext()
        let reason = "Sign in to RCForb"

        context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, authError in
            DispatchQueue.main.async {
                if success {
                    handleLogin()
                } else if let authError {
                    let code = (authError as NSError).code
                    // Don't show error for user cancel or fallback
                    if code != LAError.userCancel.rawValue && code != LAError.userFallback.rawValue {
                        error = "Authentication failed"
                    }
                }
            }
        }
    }

    private func handleLogin() {
        guard !user.isEmpty, !password.isEmpty else { return }
        loading = true
        error = ""

        Task {
            let result = await connectionManager.authenticate(user: user, password: password)
            if result.success {
                if remember {
                    CredentialStore.save(user, password)
                } else {
                    CredentialStore.clear()
                }
            } else {
                error = result.message.isEmpty ? "Login failed" : result.message
            }
            loading = false
        }
    }
}
