import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("appearance") private var appearanceRaw: String = AppAppearance.system.rawValue
    @AppStorage("autoArchiveExpired") private var autoArchiveExpired = false
    @AppStorage("autoArchiveGraceDays") private var autoArchiveGraceDays = 3
    @AppStorage("expiryReminders") private var expiryReminders = true
    @AppStorage("lowStockReminders") private var lowStockReminders = true
    @AppStorage("usageReminders") private var usageReminders = true

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
                    .font(AppFont.body)
                }

                Section {
                    Toggle("Auto-Archive Expired Items", isOn: $autoArchiveExpired)
                        .font(AppFont.body)

                    if autoArchiveExpired {
                        Stepper(
                            "Grace period: \(autoArchiveGraceDays) day\(autoArchiveGraceDays == 1 ? "" : "s")",
                            value: $autoArchiveGraceDays,
                            in: 1...30
                        )
                        .font(AppFont.body)
                    }
                } header: {
                    Text("Pantry")
                } footer: {
                    Text("Automatically archive items that have been expired for longer than the grace period.")
                }

                Section {
                    Toggle("Expiry Alerts", isOn: $expiryReminders)
                        .font(AppFont.body)
                    Toggle("Low Stock Alerts", isOn: $lowStockReminders)
                        .font(AppFont.body)
                    Toggle("Usage Review Reminders", isOn: $usageReminders)
                        .font(AppFont.body)
                } header: {
                    Text("Notifications")
                } footer: {
                    Text("Usage reminders notify you when items haven't been updated in a while.")
                }

                Section("Help & Info") {
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
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(AppFont.button)
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
