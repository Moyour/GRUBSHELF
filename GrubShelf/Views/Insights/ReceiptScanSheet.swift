import SwiftUI
import PhotosUI
import UIKit

struct ReceiptScanSheet: View {
    @Environment(\.dismiss) private var dismiss

    let financeVM: FinanceViewModel
    var onDismiss: (() -> Void)?

    @State private var selectedItem: PhotosPickerItem?
    @State private var showCameraPicker = false
    @State private var isProcessing = false
    @State private var parsedReceipt: ParsedReceipt?
    @State private var errorMessage: String?

    private var cameraAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    var body: some View {
        Group {
            if let receipt = parsedReceipt {
                ReceiptConfirmationSheet(
                    parsedReceipt: receipt,
                    financeVM: financeVM,
                    currencyCode: financeVM.currencyCode,
                    onDismiss: {
                        dismiss()
                        onDismiss?()
                    }
                )
            } else {
                NavigationStack {
                    mainContent
                        .navigationTitle("Scan receipt")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Cancel") {
                                    dismiss()
                                    onDismiss?()
                                }
                            }
                        }
                }
            }
        }
        .onChange(of: selectedItem) { _, newItem in
            guard let newItem else { return }
            Task { await processSelectedItem(newItem) }
        }
        .fullScreenCover(isPresented: $showCameraPicker) {
            CameraImagePicker { image in
                Task { await processCapturedImage(image) }
            }
            .ignoresSafeArea()
        }
    }

    private var mainContent: some View {
        VStack(spacing: AppSpacing.sectionSpacing) {
            if isProcessing {
                VStack(spacing: AppSpacing.rowSpacing) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("Reading receipt…")
                        .font(BrandFont.regular(17))
                        .foregroundStyle(.gsTextSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: AppSpacing.sectionSpacing) {
                    Image(systemName: "doc.viewfinder")
                        .font(BrandSymbolFont.symbol(34, weight: .bold))
                        .foregroundStyle(.gsBrandPrimary.opacity(0.6))

                    Text("Snap or choose a receipt")
                        .font(BrandFont.semiBold(18))
                        .foregroundStyle(.gsTextPrimary)

                    Text("We'll extract items and total to add to your pantry or shopping list.")
                        .font(BrandFont.regular(17))
                        .foregroundStyle(.gsTextSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, AppSpacing.screenPadding)

                    VStack(spacing: AppSpacing.rowSpacing) {
                        if cameraAvailable {
                            Button {
                                showCameraPicker = true
                            } label: {
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
                .padding(AppSpacing.screenPadding)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.gsBackground)
    }

    private func processSelectedItem(_ item: PhotosPickerItem) async {
        defer { selectedItem = nil }

        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else {
                errorMessage = "That photo didn’t open—try another?"
                return
            }
            await processReceiptImage(image)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func processCapturedImage(_ image: UIImage) async {
        await processReceiptImage(image)
    }

    private func processReceiptImage(_ image: UIImage) async {
        isProcessing = true
        errorMessage = nil
        defer { isProcessing = false }

        do {
            let lines = try await ReceiptOCRService.extractText(from: image)
            let receipt = ReceiptParser.parse(lines)

            if receipt.items.isEmpty {
                errorMessage = "We couldn’t read lines off that—try a sharper photo."
                return
            }

            parsedReceipt = receipt
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
