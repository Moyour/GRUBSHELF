import SwiftUI
import UserNotifications

struct SettingsView: View {
    /// When set (e.g. from Profile), user can pick which shopping list appears on the Home Screen widget.
    let householdId: UUID?
    @Bindable var profileVM: ProfileViewModel

    @Environment(\.dismiss) private var dismiss
    @Environment(\.featureGateService) private var featureGateService
    @AppStorage("appearance") private var appearanceRaw: String = AppAppearance.system.rawValue
    @AppStorage("autoArchiveExpired") private var autoArchiveExpired = false
    @AppStorage("autoArchiveGraceDays") private var autoArchiveGraceDays = 3
    @AppStorage("expiryReminders") private var expiryReminders = true
    @AppStorage("lowStockReminders") private var lowStockReminders = true
    @AppStorage("usageReminders") private var usageReminders = true
    @AppStorage("budgetReminderEnabled") private var budgetReminderEnabled = true
    @AppStorage("GrubShelf.currencyCode") private var currencyPreference: String = "GBP"
    @State private var pushAuthorizationStatus: UNAuthorizationStatus = .notDetermined

    init(householdId: UUID? = nil, profileVM: ProfileViewModel) {
        self.householdId = householdId
        self.profileVM = profileVM
    }

    private var appearance: AppAppearance {
        get { AppAppearance(rawValue: appearanceRaw) ?? .system }
        set { appearanceRaw = newValue.rawValue }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Appearance") {
                    Picker("Theme", selection: Binding(
                        get: { appearance },
                        set: { appearanceRaw = $0.rawValue }
                    )) {
                        Text("System").tag(AppAppearance.system)
                        Text("Light").tag(AppAppearance.light)
                        Text("Dark").tag(AppAppearance.dark)
                    }
                    .font(BrandFont.regular(17))
                }

                Section {
                    Toggle("Auto-archive expired items", isOn: $autoArchiveExpired)
                        .font(BrandFont.regular(17))

                    if autoArchiveExpired {
                        Stepper(
                            "Grace period: \(autoArchiveGraceDays) day\(autoArchiveGraceDays == 1 ? "" : "s")",
                            value: $autoArchiveGraceDays,
                            in: 1...30
                        )
                        .font(BrandFont.regular(17))
                    }
                } header: {
                    Text("Pantry")
                } footer: {
                    Text("When enabled, items expired for more than the grace period (default 3 days) are automatically archived. You'll be notified one day before.")
                }

                Section {
                    pushStatusRow
                    Toggle("Expiry alerts", isOn: $expiryReminders)
                        .font(BrandFont.regular(17))
                    Toggle("Low Stock Alerts", isOn: $lowStockReminders)
                        .font(BrandFont.regular(17))
                    Toggle("Usage Review Reminders", isOn: $usageReminders)
                        .font(BrandFont.regular(17))
                    Toggle("Budget Reminders", isOn: $budgetReminderEnabled)
                        .font(BrandFont.regular(17))
                    Toggle("Email digest", isOn: $profileVM.emailNotificationsEnabled)
                        .font(BrandFont.regular(17))
                        .onChange(of: profileVM.emailNotificationsEnabled) { _, _ in
                            Task { await profileVM.saveEmailNotificationPreference() }
                        }
                } header: {
                    Text("Notifications")
                } footer: {
                    Text("Usage reminders notify you when items haven't been updated in a while. Budget reminders alert when you're close to your spending limit. Email digest sends a daily summary of expiring items, low stock, and budget status.")
                }

                Section {
                    Picker("Currency", selection: $currencyPreference) {
                        ForEach(Self.supportedCurrencies, id: \.self) { code in
                            Text(code).tag(code)
                        }
                    }
                    .font(BrandFont.regular(17))
                } header: {
                    Text("Currency")
                } footer: {
                    Text("Used for formatting costs and budgets across the app.")
                }

                Section {
                    Button {
                        dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            featureGateService?.showPaywall = true
                        }
                    } label: {
                        HStack(spacing: AppSpacing.rowSpacing) {
                            Image(systemName: "star.circle.fill")
                                .font(BrandSymbolFont.symbol(22))
                                .foregroundStyle(.gsBrandPrimary)
                            VStack(alignment: .leading, spacing: AppSpacing.compactGap) {
                                Text("Upgrade to Premium")
                                    .font(BrandFont.semiBold(17))
                                    .foregroundStyle(.gsTextPrimary)
                                Text("Unlimited items, barcode scanning, data export")
                                    .font(BrandFont.regular(14))
                                    .foregroundStyle(.gsTextSecondary)
                                    .lineLimit(2)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(BrandSymbolFont.symbol(12, weight: .semibold))
                                .foregroundStyle(.gsTextSecondary)
                        }
                    }
                    .buttonStyle(.plain)
                } header: {
                    Text("Premium")
                }

                Section("Help & Info") {
                    NavigationLink {
                        HomeScreenWidgetGuideView()
                    } label: {
                        Label("Home screen widget", systemImage: "square.grid.2x2")
                    }

                    if let householdId {
                        NavigationLink {
                            WidgetShoppingListPickerView(householdId: householdId)
                        } label: {
                            Label("Widget shopping list", systemImage: "pin")
                        }
                    }

                    NavigationLink {
                        FAQView()
                    } label: {
                        Label("FAQ", systemImage: "questionmark.circle")
                    }

                    NavigationLink {
                        AboutView()
                    } label: {
                        Label("About", systemImage: "info.circle")
                    }

                    NavigationLink {
                        TermsView()
                    } label: {
                        Label("Terms & Conditions", systemImage: "doc.text")
                    }

                    NavigationLink {
                        PrivacyView()
                    } label: {
                        Label("Privacy Policy", systemImage: "hand.raised")
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(.gsBackground)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(BrandFont.semiBold(17))
                }
            }
            .task {
                let settings = await UNUserNotificationCenter.current().notificationSettings()
                pushAuthorizationStatus = settings.authorizationStatus
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                Task {
                    let settings = await UNUserNotificationCenter.current().notificationSettings()
                    pushAuthorizationStatus = settings.authorizationStatus
                }
            }
        }
    }

    @ViewBuilder
    private var pushStatusRow: some View {
        HStack {
            Label {
                Text("Push notifications")
                    .font(BrandFont.regular(17))
            } icon: {
                Image(systemName: pushStatusIcon)
                    .foregroundStyle(pushStatusColor)
            }
            Spacer()
            if pushAuthorizationStatus == .denied {
                Button("Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                .font(BrandFont.semiBold(15))
                .foregroundStyle(.gsBrandPrimary)
            } else {
                Text(pushStatusLabel)
                    .font(BrandFont.regular(15))
                    .foregroundStyle(.gsTextSecondary)
            }
        }
    }

    private var pushStatusIcon: String {
        switch pushAuthorizationStatus {
        case .authorized, .provisional, .ephemeral: "bell.badge.fill"
        case .denied: "bell.slash.fill"
        default: "bell"
        }
    }

    private var pushStatusColor: Color {
        switch pushAuthorizationStatus {
        case .authorized, .provisional, .ephemeral: .gsSuccess
        case .denied: .gsDanger
        default: .gsTextSecondary
        }
    }

    static let supportedCurrencies = ["GBP", "USD", "EUR", "NGN", "CAD", "AUD", "JPY", "INR", "ZAR", "GHS", "KES"]

    private var pushStatusLabel: String {
        switch pushAuthorizationStatus {
        case .authorized, .provisional, .ephemeral: "Enabled"
        case .denied: "Disabled"
        default: "Not set up"
        }
    }
}

// MARK: - Appearance

enum AppAppearance: String, CaseIterable {
    case system
    case light
    case dark

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}
