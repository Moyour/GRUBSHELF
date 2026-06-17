import SwiftUI

/// View for accepting household invitations - handles both existing and new users
struct AcceptInviteView: View {
    @Bindable var authService: AuthenticationService
    @Environment(\.dismiss) private var dismiss
    
    let inviteToken: UUID
    
    @State private var inviteDetails: HouseholdInviteWithName?
    @State private var isLoadingInvite = true
    @State private var inviteError: String?
    
    // New user fields
    @State private var name = ""
    @State private var password = ""
    @State private var showPassword = false
    @State private var isCreatingAccount = false
    
    var body: some View {
        NavigationStack {
            Group {
                if isLoadingInvite {
                    loadingView
                } else if let error = inviteError {
                    errorView(message: error)
                } else if let invite = inviteDetails {
                    if invite.isExpired {
                        expiredView
                    } else {
                        inviteContentView(invite: invite)
                    }
                }
            }
            .navigationTitle("Join Household")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .task {
            await loadInviteDetails()
        }
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: AppSpacing.mediumSpacing) {
            ProgressView()
            Text("Loading invitation...")
                .font(BrandFont.regular(15))
                .foregroundStyle(.gsTextSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Error View
    
    private func errorView(message: String) -> some View {
        VStack(spacing: AppSpacing.mediumSpacing) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.gsWarning)
            
            Text("Unable to Load Invitation")
                .font(BrandFont.semiBold(20))
                .foregroundStyle(.gsTextPrimary)
            
            Text(message)
                .font(BrandFont.regular(15))
                .foregroundStyle(.gsTextSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppSpacing.screenPadding)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Expired View
    
    private var expiredView: some View {
        VStack(spacing: AppSpacing.mediumSpacing) {
            Image(systemName: "clock.badge.xmark")
                .font(.system(size: 48))
                .foregroundStyle(.gsTextSecondary)
            
            Text("Invitation Expired")
                .font(BrandFont.semiBold(20))
                .foregroundStyle(.gsTextPrimary)
            
            Text("This invitation has expired. Please ask the household admin to send you a new invitation.")
                .font(BrandFont.regular(15))
                .foregroundStyle(.gsTextSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppSpacing.screenPadding)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Invite Content View
    
    private func inviteContentView(invite: HouseholdInviteWithName) -> some View {
        Form {
            // Invitation header
            Section {
                VStack(spacing: AppSpacing.mediumSpacing) {
                    Image(systemName: "house.circle.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(.gsBrandPrimary)
                    
                    VStack(spacing: AppSpacing.compactGap) {
                        Text("You're Invited!")
                            .font(BrandFont.bold(24))
                            .foregroundStyle(.gsTextPrimary)
                        
                        Text("to join")
                            .font(BrandFont.regular(15))
                            .foregroundStyle(.gsTextSecondary)
                        
                        Text(invite.householdName)
                            .font(BrandFont.semiBold(20))
                            .foregroundStyle(.gsBrandPrimary)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.mediumSpacing)
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())
            
            // Invited email
            Section {
                LabeledContent {
                    Text(invite.invitedEmail)
                        .font(BrandFont.regular(15))
                        .foregroundStyle(.gsTextPrimary)
                } label: {
                    Text("Invited Email")
                        .font(BrandFont.regular(15))
                        .foregroundStyle(.gsTextSecondary)
                }
            }
            
            // Expiration info
            Section {
                HStack {
                    Image(systemName: "clock")
                        .foregroundStyle(.gsTextSecondary)
                    Text("Expires in ")
                        .font(BrandFont.regular(15))
                        .foregroundStyle(.gsTextSecondary)
                    + Text(invite.expiresAt, style: .relative)
                        .font(BrandFont.semiBold(15))
                        .foregroundColor(.gsBrandPrimary)
                }
            }
            
            // New user account creation
            Section {
                TextField("Your name", text: $name)
                    .textContentType(.name)
                    .autocorrectionDisabled()
                
                HStack {
                    if showPassword {
                        TextField("Create password", text: $password)
                            .textContentType(.newPassword)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    } else {
                        SecureField("Create password", text: $password)
                            .textContentType(.newPassword)
                    }
                    Button {
                        showPassword.toggle()
                    } label: {
                        Image(systemName: showPassword ? "eye.slash" : "eye")
                            .font(BrandSymbolFont.symbol(17, weight: .regular))
                            .foregroundStyle(.gsTextSecondary)
                    }
                    .buttonStyle(.plain)
                }
            } header: {
                Text("Create Your Account")
            } footer: {
                VStack(alignment: .leading, spacing: AppSpacing.compactGap) {
                    Text("We'll create a GrubShelf account for you with this email and password.")
                        .font(BrandFont.regular(13))
                    
                    if !password.isEmpty {
                        PasswordStrengthBar(
                            level: passwordStrengthLevel,
                            label: passwordStrengthLabel,
                            color: passwordStrengthColor,
                            unmetRequirements: unmetPasswordRequirements
                        )
                        .padding(.top, 4)
                    }
                }
            }
            
            // Error message
            if let error = authService.errorMessage {
                Section {
                    Text(error)
                        .font(BrandFont.regular(14))
                        .foregroundStyle(.gsDanger)
                }
            }
            
            // Accept button
            Section {
                Button {
                    Task {
                        await acceptInviteAndCreateAccount(invite: invite)
                    }
                } label: {
                    if isCreatingAccount {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Accept & Create Account")
                            .font(BrandFont.semiBold(17))
                            .frame(maxWidth: .infinity)
                    }
                }
                .disabled(isCreatingAccount || !isFormValid)
            } footer: {
                Text("By continuing, you agree to the GrubShelf Terms of Service and Privacy Policy.")
                    .font(BrandFont.regular(12))
                    .foregroundStyle(.gsTextSecondary)
            }
        }
        .scrollContentBackground(.hidden)
        .background(.gsBackground)
    }
    
    // MARK: - Actions
    
    private func loadInviteDetails() async {
        isLoadingInvite = true
        inviteError = nil
        
        let householdService = HouseholdService()
        do {
            // Fetch invite details using the new service method
            let invite = try await householdService.fetchInviteByToken(inviteToken: inviteToken)
            inviteDetails = invite
        } catch {
            inviteError = "Could not load invitation details. The link may be invalid or the invitation may have been cancelled."
        }
        isLoadingInvite = false
    }
    
    private func acceptInviteAndCreateAccount(invite: HouseholdInviteWithName) async {
        isCreatingAccount = true
        authService.errorMessage = nil
        
        // Step 1: Create the account with email and password
        await authService.signUp(email: invite.invitedEmail, password: password, name: name.trimmingCharacters(in: .whitespaces))
        
        // Check if sign up was successful
        guard authService.isAuthenticated else {
            isCreatingAccount = false
            return
        }
        
        // Step 2: Accept the invitation
        let householdService = HouseholdService()
        do {
            let updatedUser = try await householdService.acceptInvite(inviteId: invite.inviteId)
            authService.currentUser = updatedUser
            
            ToastManager.shared.show("Welcome to \(invite.householdName)!", style: .success)
            dismiss()
        } catch {
            authService.errorMessage = "Account created, but failed to accept invitation: \(error.localizedDescription)"
        }
        
        isCreatingAccount = false
    }
    
    // MARK: - Validation
    
    private var isFormValid: Bool {
        let nameValid = !name.trimmingCharacters(in: .whitespaces).isEmpty
        let passwordValid = isPasswordStrong
        return nameValid && passwordValid
    }
    
    private var hasSpecialCharacter: Bool {
        let specialCharacters = CharacterSet.alphanumerics.inverted
        return password.unicodeScalars.contains(where: { specialCharacters.contains($0) })
    }
    
    private var isPasswordStrong: Bool {
        password.count >= 8 &&
        password.contains(where: \.isUppercase) &&
        password.contains(where: \.isLowercase) &&
        password.contains(where: \.isNumber) &&
        hasSpecialCharacter
    }
    
    private var passwordStrengthLevel: Int {
        var level = 0
        if password.count >= 8 { level += 1 }
        if password.count >= 8 && password.contains(where: \.isUppercase) && password.contains(where: \.isLowercase) { level += 1 }
        if isPasswordStrong { level += 1 }
        return level
    }
    
    private var passwordStrengthLabel: String {
        switch passwordStrengthLevel {
        case 0: return "Weak"
        case 1: return "Weak"
        case 2: return "Medium"
        default: return "Strong"
        }
    }
    
    private var passwordStrengthColor: Color {
        switch passwordStrengthLevel {
        case 0, 1: return .gsTextSecondary
        case 2: return .gsTextSecondary
        default: return .gsBrandPrimary
        }
    }
    
    private var unmetPasswordRequirements: [String] {
        var reqs: [String] = []
        if password.count < 8 { reqs.append("At least 8 characters") }
        if !password.contains(where: \.isUppercase) { reqs.append("At least 1 uppercase letter") }
        if !password.contains(where: \.isLowercase) { reqs.append("At least 1 lowercase letter") }
        if !password.contains(where: \.isNumber) { reqs.append("At least 1 number") }
        if !hasSpecialCharacter { reqs.append("At least 1 special character (!@#$%...)") }
        return reqs
    }
}

