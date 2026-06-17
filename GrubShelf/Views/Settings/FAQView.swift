import SwiftUI

struct FAQView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.sectionSpacing) {
                FAQItem(
                    question: "How do I add items to my pantry?",
                    answer: "On the Home tab, tap + in the toolbar or use Add item in Quick actions. You can enter items manually or search the grocery catalog."
                )
                FAQItem(
                    question: "How does household sharing work?",
                    answer: "From the Today (Home) tab, open Profile, then invite family members. Only household admins can send invites. Each member sees the same pantry and shopping lists. Admins can manage roles and remove members."
                )
                FAQItem(
                    question: "How do I transfer shopping items to my pantry?",
                    answer: "Complete items on your shopping list, then tap Transfer to Pantry. Confirm quantities and the items will be added to your pantry with a transaction record."
                )
                FAQItem(
                    question: "When do expiry reminders appear?",
                    answer: "Items expiring today trigger an immediate alert. Other items expiring within 3 days are included in your daily pantry check-in. Enable Expiry Alerts in Settings to receive these notifications."
                )
                FAQItem(
                    question: "What is the low stock threshold?",
                    answer: "Each pantry item has a low stock threshold (default 1). When quantity falls at or below it, you'll see a low stock indicator and can get reminders."
                )
                FAQItem(
                    question: "How does the budget feature work?",
                    answer: "Set a monthly or weekly budget under Expense. Track spending from shopping transfers and see how much you've used vs remaining."
                )
            }
            .padding(AppSpacing.screenPadding)
        }
        .background(.gsBackground)
        .navigationTitle("FAQ")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct FAQItem: View {
    let question: String
    let answer: String

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.rowSpacing) {
            Text(question)
                .font(BrandFont.semiBold(17))
                .foregroundStyle(.gsTextPrimary)
            Text(answer)
                .font(BrandFont.regular(17))
                .foregroundStyle(.gsTextSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.cardPadding)
        .dashboardCardSurface()
    }
}
