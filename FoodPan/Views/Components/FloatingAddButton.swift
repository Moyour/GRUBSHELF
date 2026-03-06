import SwiftUI

struct FloatingAddButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: {
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
            action()
        }) {
            Image(systemName: "plus")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(Color.primaryGreen)
                .clipShape(Circle())
                .cardShadow()
        }
        .accessibilityLabel("Add item")
        .accessibilityHint("Double tap to add a new pantry item")
    }
}
