import SwiftUI

struct ValidationErrorText: View {
    let error: String?

    var body: some View {
        if let error, !error.isEmpty {
            Text(error)
                .font(AppFont.caption)
                .foregroundStyle(Color.errorRed)
                .transition(.opacity)
        }
    }
}
