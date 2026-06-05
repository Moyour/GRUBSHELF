import SwiftUI

struct BudgetSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss

    let userId: UUID
    var canEditBudget: Bool = true
    @State private var budgetPeriod: BudgetPeriod = .monthly
    @State private var budgetAmountText = ""
    @State private var periodStartDay = 1
    @State private var currency = "GBP"
    @State private var isSaving = false
    @State private var isLoaded = false

    private let repository: FinanceSettingsRepository = SupabaseFinanceSettingsRepository()

    private let currencies = ["GBP", "USD", "EUR", "NGN", "CAD", "AUD"]

    private var isBudgetValid: Bool {
        guard !budgetAmountText.isEmpty else { return true } // Empty is OK (user hasn't typed yet)
        guard let amount = Double(budgetAmountText) else { return false }
        return amount > 0
    }

    private var budgetErrorMessage: String? {
        guard !budgetAmountText.isEmpty else { return nil }
        guard let amount = Double(budgetAmountText) else {
            return "Must be a valid number"
        }
        if amount <= 0 {
            return "Budget must be greater than 0"
        }
        return nil
    }

    var body: some View {
        NavigationStack {
            Form {
                if !canEditBudget {
                    Section {
                        Text("Only household admins can edit budget settings. You can still view spending in Expense.")
                            .font(BrandFont.regular(14))
                            .foregroundStyle(.gsTextSecondary)
                    }
                }

                Section {
                    Picker("Period", selection: $budgetPeriod) {
                        Text("Weekly").tag(BudgetPeriod.weekly)
                        Text("Monthly").tag(BudgetPeriod.monthly)
                    }
                    .font(BrandFont.regular(17))
                    .disabled(!canEditBudget)

                    VStack(alignment: .leading, spacing: AppSpacing.compactGap) {
                        HStack {
                            Text("Budget")
                                .font(BrandFont.regular(17))
                            Spacer()
                            TextField("0.00", text: $budgetAmountText)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .font(BrandFont.regular(17))
                                .frame(maxWidth: 120)
                                .disabled(!canEditBudget)
                        }

                        if let errorMessage = budgetErrorMessage {
                            Text(errorMessage)
                                .font(BrandFont.regular(13))
                                .foregroundStyle(.gsDanger)
                        }
                    }

                    // period_start_day picker hidden — neither app nor digest uses this value yet.
                    // Re-enable once period boundaries respect the chosen start day in both Swift and the digest Edge Function.

                    Picker("Currency", selection: $currency) {
                        ForEach(currencies, id: \.self) { c in
                            Text(c).tag(c)
                        }
                    }
                    .font(BrandFont.regular(17))
                    .disabled(!canEditBudget)
                } header: {
                    Text("Budget settings")
                }
            }
            .scrollContentBackground(.hidden)
            .background(.gsBackground)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                if canEditBudget {
                    ToolbarItem(placement: .confirmationAction) {
                        Button {
                            Task { await save() }
                        } label: {
                            if isSaving {
                                ProgressView()
                            } else {
                                Text("Save")
                            }
                        }
                        .disabled(isSaving || !isBudgetValid)
                    }
                }
            }
            .task { await loadSettings() }
        }
    }

    private func loadSettings() async {
        guard !isLoaded else { return }
        do {
            if let settings = try await repository.fetch(userId: userId) {
                budgetPeriod = settings.budgetPeriod
                budgetAmountText = settings.budgetAmountMinor > 0
                    ? String(format: "%.2f", Double(settings.budgetAmountMinor) / 100.0)
                    : ""
                periodStartDay = settings.periodStartDay
                currency = settings.currency
            }
        } catch {
            // No existing settings — use defaults
        }
        isLoaded = true
    }

    private func save() async {
        guard let amount = Double(budgetAmountText), amount > 0 else {
            ToastManager.shared.show("Enter a valid budget amount", style: .error)
            return
        }
        isSaving = true

        let settings = FinanceSettings(
            userId: userId,
            budgetPeriod: budgetPeriod,
            budgetAmountMinor: Int(amount * 100),
            periodStartDay: periodStartDay,
            currency: currency
        )

        do {
            _ = try await repository.upsert(settings)
            ToastManager.shared.show("Budget saved", style: .success)
            dismiss()
        } catch {
            ToastManager.shared.show("Failed to save budget", style: .error)
        }

        isSaving = false
    }

    private func ordinal(_ day: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .ordinal
        return formatter.string(from: NSNumber(value: day)) ?? "\(day)"
    }
}
