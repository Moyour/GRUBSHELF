import SwiftUI

struct FAQView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.sectionSpacing) {
                FAQItem(
                    question: "How do I add items to my pantry?",
                    answer: "Tap the + button on the Pantry tab, or use the Add Item quick action from the Dashboard. You can add items manually or search the grocery catalog."
                )
                FAQItem(
                    question: "How does household sharing work?",
                    answer: "Invite family members from your Profile. Each member sees the same pantry and shopping lists. Admins can manage roles and remove members."
                )
                FAQItem(
                    question: "How do I transfer shopping items to my pantry?",
                    answer: "Complete items on your shopping list, then tap Transfer to Pantry. Confirm quantities and the items will be added to your pantry with a transaction record."
                )
                FAQItem(
                    question: "When do expiry reminders appear?",
                    answer: "You'll receive alerts for items expiring within 3 days. Enable Expiry Alerts in Settings to get these notifications."
                )
                FAQItem(
                    question: "What is the low stock threshold?",
                    answer: "Each pantry item has a low stock threshold (default 1). When quantity falls at or below it, you'll see a low stock indicator and can get reminders."
                )
                FAQItem(
                    question: "How does the budget feature work?",
                    answer: "Set a monthly or weekly budget in the Insights tab. Track spending from shopping transfers and see how much you've used vs remaining."
                )
            }
            .padding(AppSpacing.screenPadding)
        }
        .background(Color.appBackground)
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
                .font(AppFont.button)
                .foregroundStyle(Color.primaryText)
            Text(answer)
                .font(AppFont.body)
                .foregroundStyle(Color.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.cardPadding)
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardRadius))
        .cardShadow()
    }
}
