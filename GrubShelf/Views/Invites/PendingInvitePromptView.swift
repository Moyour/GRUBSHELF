import SwiftUI

struct PendingInvitePromptView: View {
    let invite: HouseholdInviteWithName
    let authService: AuthenticationService
    
    @Environment(\.dismiss) private var dismiss
    @State private var isAccepting = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Icon
                ZStack {
                    Circle()
                        .fill(Color.gsBrandPrimary.opacity(0.12))
                        .frame(width: 80, height: 80)
                    
                    Text("🏠")
                        .font(.system(size: 40))
                }
                .padding(.top, 32)
                
                // Title & Message
                VStack(spacing: 12) {
                    Text("You're Invited!")
                        .font(BrandFont.bold(24))
                        .foregroundStyle(.gsBrandPrimary)
                    
                    VStack(spacing: 8) {
                        Text("You have a pending invitation to join")
                            .font(BrandFont.regular(17))
                            .foregroundStyle(.gsTextSecondary)
                            .multilineTextAlignment(.center)
                        
                        Text(invite.householdName)
                            .font(BrandFont.semiBold(20))
                            .foregroundStyle(.gsBrandPrimary)
                            .multilineTextAlignment(.center)
                    }
                }
                
                // Info Card
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        Image(systemName: "envelope.fill")
                            .foregroundStyle(.gsBrandPrimary)
                            .font(.system(size: 16))
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Invited Email")
                                .font(BrandFont.regular(13))
                                .foregroundStyle(.gsTextSecondary)
                            Text(invite.invitedEmail)
                                .font(BrandFont.medium(15))
                                .foregroundStyle(.gsTextPrimary)
                        }
                        
                        Spacer()
                    }
                    
                    if !invite.isExpired {
                        HStack(spacing: 12) {
                            Image(systemName: "clock.fill")
                                .foregroundStyle(.gsBrandPrimary)
                                .font(.system(size: 16))
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Expires")
                                    .font(BrandFont.regular(13))
                                    .foregroundStyle(.gsTextSecondary)
                                Text(invite.expiresAt, style: .relative)
                                    .font(BrandFont.regular(17))
                                    .foregroundStyle(.gsTextPrimary)
                            }
                            
                            Spacer()
                        }
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gsBackground)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.gsTextSecondary.opacity(0.2), lineWidth: 1)
                )
                
                Spacer()
                
                // Action Buttons
                VStack(spacing: 12) {
                    Button {
                        acceptInvite()
                    } label: {
                        if isAccepting {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Accept Invitation")
                                .font(BrandFont.semiBold(17))
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.gsBrandPrimary)
                    .disabled(isAccepting)
                    
                    Button {
                        declineInvite()
                    } label: {
                        Text("Not Now")
                            .font(BrandFont.medium(17))
                            .foregroundStyle(.gsTextSecondary)
                    }
                    .disabled(isAccepting)
                }
            }
            .padding(24)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        declineInvite()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.gsTextSecondary)
                    }
                    .disabled(isAccepting)
                }
            }
        }
        .presentationDetents([.height(500)])
        .presentationDragIndicator(.visible)
        .interactiveDismissDisabled(isAccepting)
    }
    
    private func acceptInvite() {
        isAccepting = true
        Task {
            do {
                try await authService.acceptPendingInvite(inviteId: invite.inviteId)
                
                await MainActor.run {
                    ToastManager.shared.show("Welcome to \(invite.householdName)!", style: .success)
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isAccepting = false
                    ToastManager.shared.show("Failed to accept invitation: \(error.localizedDescription)", style: .error)
                }
            }
        }
    }
    
    private func declineInvite() {
        authService.dismissPendingInvite(inviteId: invite.inviteId)
        dismiss()
    }
}

#Preview {
    PendingInvitePromptView(
        invite: HouseholdInviteWithName(
            inviteId: UUID(),
            householdId: UUID(),
            invitedEmail: "friend@example.com",
            invitedBy: UUID(),
            status: .pending,
            createdAt: Date(),
            expiresAt: Date().addingTimeInterval(86400 * 7),
            households: .init(name: "The Smith Family")
        ),
        authService: AuthenticationService()
    )
}
