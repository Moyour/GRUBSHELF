import SwiftUI

struct ValidationErrorText: View {
    let error: String?

    var body: some View {
        if let error, !error.isEmpty {
            Text(error)
                .font(BrandFont.regular(14))
                .foregroundStyle(.gsDanger)
                .transition(.opacity)
        }
    }
}
