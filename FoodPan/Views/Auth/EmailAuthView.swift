import SwiftUI

struct EmailAuthView: View {
    @Bindable var authService: AuthenticationService
    @Environment(\.dismiss) private var dismiss

    @State private var isSignUp = false
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""

    var body: some View {
        NavigationStack {
            Form {
                if isSignUp {
                    Section("Name") {
                        TextField("Your name", text: $name)
                            .textContentType(.name)
                            .autocorrectionDisabled()
                    }
                }

                Section("Credentials") {
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()

                    SecureField("Password", text: $password)
                        .textContentType(isSignUp ? .newPassword : .password)
                }

                if let error = authService.errorMessage {
                    Section {
                        Text(error)
                            .font(AppFont.caption)
                            .foregroundStyle(Color.errorRed)
                    }
                }

                Section {
                    Button {
                        Task {
                            if isSignUp {
                                await authService.signUp(email: email, password: password, name: name)
                            } else {
                                await authService.signIn(email: email, password: password)
                            }
                            if authService.isAuthenticated { dismiss() }
                        }
                    } label: {
                        if authService.isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text(isSignUp ? "Create Account" : "Sign In")
                                .font(AppFont.button)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(authService.isLoading || !isFormValid)
                }

                Section {
                    Button {
                        isSignUp.toggle()
                        authService.errorMessage = nil
                    } label: {
                        Text(isSignUp ? "Already have an account? Sign In" : "Don't have an account? Sign Up")
                            .font(AppFont.caption)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .navigationTitle(isSignUp ? "Create Account" : "Sign In")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private var isFormValid: Bool {
        let emailValid = email.contains("@") && email.contains(".")
        let passwordValid = password.count >= 6
        let nameValid = !isSignUp || !name.trimmingCharacters(in: .whitespaces).isEmpty
        return emailValid && passwordValid && nameValid
    }
}
