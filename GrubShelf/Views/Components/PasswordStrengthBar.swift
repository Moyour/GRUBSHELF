import SwiftUI

struct PasswordStrengthBar: View {
    let level: Int
    let label: String
    let color: Color
    let unmetRequirements: [String]

    var body: some View {
        Group {
            HStack(spacing: AppSpacing.compactGap) {
                ForEach(0..<3, id: \.self) { index in
                    RoundedRectangle(cornerRadius: AppSpacing.microGap)
                        .fill(index < level ? color : Color.gsShimmer.opacity(0.3))
                        .frame(height: AppSpacing.compactGap)
                }
            }

            Text(label)
                .font(BrandFont.regular(14))
                .foregroundStyle(color)

            ForEach(unmetRequirements, id: \.self) { req in
                Label(req, systemImage: "xmark.circle")
                    .font(BrandFont.regular(14))
                    .foregroundStyle(.gsTextSecondary)
            }
        }
    }
}
