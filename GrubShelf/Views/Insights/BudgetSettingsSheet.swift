import SwiftUI

struct BudgetSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss

    let userId: UUID
    @State private var budgetPeriod: BudgetPeriod = .monthly
    @State private var budgetAmountText = ""
    @State private var periodStartDay = 1
    @State private var currency = "GBP"
    @State private var isSaving = false
    @State private var isLoaded = false

    private let repository: FinanceSettingsRepository = SupabaseFinanceSettingsRepository()

    private let currencies = ["GBP", "USD", "EUR", "NGN", "CAD", "AUD"]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Period", selection: $budgetPeriod) {
                        Text("Weekly").tag(BudgetPeriod.weekly)
                        Text("Monthly").tag(BudgetPeriod.monthly)
                    }
                    .font(BrandFont.regular(17))

                    HStack {
                        Text("Budget")
                            .font(BrandFont.regular(17))
                        Spacer()
                        TextField("0.00", text: $budgetAmountText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .font(BrandFont.regular(17))
                            .frame(maxWidth: 120)
                    }

                    if budgetPeriod == .weekly {
                        Picker("Start day", selection: $periodStartDay) {
                            ForEach(1...7, id: \.self) { day in
                                Text(Calendar.current.weekdaySymbols[day % 7]).tag(day)
                            }
                        }
                        .font(BrandFont.regular(17))
                    } else {
                        Picker("Start day", selection: $periodStartDay) {
                            ForEach(1...28, id: \.self) { day in
                                Text(ordinal(day)).tag(day)
                            }
                        }
                        .font(BrandFont.regular(17))
                    }

                    Picker("Currency", selection: $currency) {
                        ForEach(currencies, id: \.self) { c in
                            Text(c).tag(c)
                        }
                    }
                    .font(BrandFont.regular(17))
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
                    .disabled(isSaving)
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
