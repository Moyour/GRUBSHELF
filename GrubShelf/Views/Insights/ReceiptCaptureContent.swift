import SwiftUI
import PhotosUI

/// Capture UI embedded in [`ReceiptFlowSheet`] (camera, library, processing).
struct ReceiptCaptureContent: View {
    let cameraAvailable: Bool
    let isProcessing: Bool
    var errorMessage: String?
    @Binding var selectedItem: PhotosPickerItem?
    var onTakePhoto: () -> Void

    var body: some View {
        VStack(spacing: AppSpacing.sectionSpacing) {
            if isProcessing {
                VStack(spacing: AppSpacing.rowSpacing) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("Reading receipt…")
                        .font(BrandFont.regular(17))
                        .foregroundStyle(.gsTextSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.sectionSpacing)
            } else {
                Image(systemName: "doc.viewfinder")
                    .font(BrandSymbolFont.symbol(34, weight: .bold))
                    .foregroundStyle(.gsBrandPrimary.opacity(0.6))

                Text("Snap or choose a receipt")
                    .font(BrandFont.semiBold(18))
                    .foregroundStyle(.gsTextPrimary)

                Text("We'll read the total for your budget and Expenses.")
                    .font(BrandFont.regular(17))
                    .foregroundStyle(.gsTextSecondary)
                    .multilineTextAlignment(.center)

                VStack(spacing: AppSpacing.rowSpacing) {
                    if cameraAvailable {
                        Button(action: onTakePhoto) {
                            Label("Take Photo", systemImage: "camera")
                                .font(BrandFont.semiBold(17))
                                .foregroundStyle(.gsTextInverse)
                                .frame(maxWidth: .infinity)
                                .frame(height: AppSpacing.minTouchTarget)
                                .background(.gsBrandPrimary)
                                .clipShape(RoundedRectangle(cornerRadius: AppSpacing.buttonRadius))
                        }
                        .disabled(isProcessing)
                    }

                    PhotosPicker(
                        selection: $selectedItem,
                        matching: .images,
                        photoLibrary: .shared()
                    ) {
                        Label("Choose from Library", systemImage: "photo.on.rectangle.angled")
                            .font(BrandFont.semiBold(17))
                            .foregroundStyle(cameraAvailable ? .gsBrandPrimary : .gsTextInverse)
                            .frame(maxWidth: .infinity)
                            .frame(height: AppSpacing.minTouchTarget)
                            .background(cameraAvailable ? AnyShapeStyle(.gsSurface) : AnyShapeStyle(.gsBrandPrimary))
                            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.buttonRadius))
                            .overlay(
                                RoundedRectangle(cornerRadius: AppSpacing.buttonRadius)
                                    .stroke(cameraAvailable ? Color.gsBrandPrimary : Color.clear, lineWidth: 1)
                            )
                    }
                    .disabled(isProcessing)
                }

                if let error = errorMessage {
                    Text(error)
                        .font(BrandFont.regular(14))
                        .foregroundStyle(.gsDanger)
                        .multilineTextAlignment(.center)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
}
