import SwiftUI

struct SettingsView: View {
    /// When set (e.g. from Profile), user can pick which shopping list appears on the Home Screen widget.
    let householdId: UUID?
    @Bindable var profileVM: ProfileViewModel

    @Environment(\.dismiss) private var dismiss
    @AppStorage("appearance") private var appearanceRaw: String = AppAppearance.system.rawValue
    @AppStorage("autoArchiveExpired") private var autoArchiveExpired = false
    @AppStorage("autoArchiveGraceDays") private var autoArchiveGraceDays = 3
    @AppStorage("expiryReminders") private var expiryReminders = true
    @AppStorage("lowStockReminders") private var lowStockReminders = true
    @AppStorage("usageReminders") private var usageReminders = true
    @AppStorage("budgetReminderEnabled") private var budgetReminderEnabled = true

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
                    Text("Automatically archive items that have been expired for longer than the grace period. You'll be notified one day before items are archived.")
                }

                Section {
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
