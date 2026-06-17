import SwiftUI
import PhotosUI
import UIKit

/// Single-sheet log purchase: receipt capture, confirm, and manual entry in one flow.
struct ReceiptFlowSheet: View {
    @Environment(\.dismiss) private var dismiss

    @Bindable var financeVM: FinanceViewModel
    var pantryRepository: PantryRepository?
    var userRole: UserRole
    var onDismiss: (() -> Void)?

    @State private var confirmViewModel: ReceiptConfirmationViewModel
    @State private var parsedReceipt: ParsedReceipt?
    @State private var selectedItem: PhotosPickerItem?
    @State private var showCameraPicker = false
    @State private var isProcessing = false
    @State private var captureErrorMessage: String?

    init(
        financeVM: FinanceViewModel,
        pantryRepository: PantryRepository? = nil,
        userRole: UserRole = .member,
        onDismiss: (() -> Void)? = nil
    ) {
        self.financeVM = financeVM
        self.pantryRepository = pantryRepository
        self.userRole = userRole
        self.onDismiss = onDismiss
        _confirmViewModel = State(initialValue: ReceiptConfirmationViewModel(
            pantryRepository: pantryRepository,
            householdId: financeVM.householdId,
            userId: financeVM.userId,
            userRole: userRole
        ))
    }

    private var cameraAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    private var currencySymbol: String {
        Locale.currencySymbol(for: financeVM.currencyCode)
    }

    private var isConfirmPhase: Bool {
        parsedReceipt != nil
    }

    /// Button label changes when pantry items will be added.
    private var footerButtonLabel: String {
        if confirmViewModel.canAddToPantry
            && confirmViewModel.addToPantryEnabled
            && confirmViewModel.pantrySelectionCount > 0
            && isConfirmPhase {
            return "Log & add to pantry"
        }
        return "Log purchase"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.sectionSpacing) {
                    if isConfirmPhase {
                        ReceiptConfirmContent(
                            viewModel: confirmViewModel,
                            currencyCode: financeVM.currencyCode,
                            onRescan: rescan
                        )
                    } else {
                        manualEntrySection

                        ReceiptCaptureContent(
                            cameraAvailable: cameraAvailable,
                            isProcessing: isProcessing,
                            errorMessage: captureErrorMessage,
                            selectedItem: $selectedItem,
                            onTakePhoto: { showCameraPicker = true }
                        )
                    }
                }
                .padding(AppSpacing.screenPadding)
            }
            .background(.gsBackground)
            .navigationTitle("Log purchase")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                logPurchaseFooter
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                        onDismiss?()
                    }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                    .font(BrandFont.semiBold(15))
                }
            }
            .task {
                await confirmViewModel.loadSuggestedTotalIfNeeded(householdId: financeVM.householdId)
            }
            .onChange(of: selectedItem) { _, newItem in
                guard let newItem else { return }
                Task { await processSelectedItem(newItem) }
            }
            .fullScreenCover(isPresented: $showCameraPicker) {
                CameraImagePicker { image in
                    Task { await processReceiptImage(image) }
                }
                .ignoresSafeArea()
            }
            .onAppear {
                wireSuccessHandler()
            }
            .overlay {
                if isProcessing {
                    ZStack {
                        Color.black.opacity(0.4)
                            .ignoresSafeArea()

                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.5)
                                .tint(.white)

                            Text("Reading receipt...")
                                .font(BrandFont.semiBold(17))
                                .foregroundStyle(.white)
                        }
                        .padding(32)
                        .background(.regularMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                }
            }
        }
    }

    // MARK: - Manual entry (no scan)

    private var manualEntrySection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.rowSpacing) {
            Text("Enter manually")
                .font(BrandFont.semiBold(17))
                .foregroundStyle(.gsTextPrimary)

            Text("Bought something off-list? Log it here so your budget stays honest.")
                .font(BrandFont.regular(14))
                .foregroundStyle(.gsTextSecondary)

            VStack(alignment: .leading, spacing: AppSpacing.rowSpacing) {
                DatePicker("Date", selection: $confirmViewModel.date, displayedComponents: .date)
                    .font(BrandFont.regular(17))

                TextField("Store (optional)", text: $confirmViewModel.storeName)
                    .font(BrandFont.regular(17))
                    .textInputAutocapitalization(.words)

                HStack {
                    Text("Amount")
                        .font(BrandFont.regular(17))
                    Spacer()
                    HStack(spacing: AppSpacing.compactGap) {
                        Text(currencySymbol)
                            .font(BrandFont.regular(17))
                            .foregroundStyle(.gsTextSecondary)
                        TextField("0.00", text: $confirmViewModel.manualTotalText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .font(BrandFont.regular(17))
                            .frame(maxWidth: 120)
                            .onChange(of: confirmViewModel.manualTotalText) { _, _ in
                                confirmViewModel.didPrefillTotal = false
                            }
                    }
                }

                if confirmViewModel.didPrefillTotal {
                    Text("Prefilled from your last shop")
                        .font(BrandFont.regular(13))
                        .foregroundStyle(.gsBrandPrimary.opacity(0.9))
                }
            }
            .padding(AppSpacing.cardPadding)
            .dashboardCardSurface()

            if let error = confirmViewModel.errorMessage, !isConfirmPhase {
                Text(error)
                    .font(BrandFont.regular(14))
                    .foregroundStyle(.gsDanger)
            }
        }
    }

    // MARK: - Footer

    private var logPurchaseFooter: some View {
        VStack(alignment: .leading, spacing: AppSpacing.compactGap) {
            if !confirmViewModel.canLogPurchase {
                Text("Enter an amount above (greater than 0) to log this purchase.")
                    .font(BrandFont.regular(13))
                    .foregroundStyle(.gsTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Button {
                Task {
                    await confirmViewModel.logPurchase(using: financeVM)
                }
            } label: {
                Group {
                    if confirmViewModel.isSaving {
                        ProgressView()
                            .tint(.gsTextOnBrand)
                    } else {
                        Text(footerButtonLabel)
                            .font(BrandFont.semiBold(17))
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: AppSpacing.minTouchTarget)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.gsTextOnBrand)
            .background(
                confirmViewModel.canLogPurchase && !confirmViewModel.isSaving
                    ? Color.gsBrandPrimary
                    : Color.gsBrandPrimary.opacity(0.35)
            )
            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.buttonRadius, style: .continuous))
            .disabled(confirmViewModel.isSaving || !confirmViewModel.canLogPurchase)
        }
        .padding(AppSpacing.screenPadding)
        .frame(maxWidth: .infinity)
        .background(.gsBackground)
    }

    // MARK: - OCR

    private func rescan() {
        parsedReceipt = nil
        captureErrorMessage = nil
        confirmViewModel = makeConfirmViewModel()
        wireSuccessHandler()
        Task {
            await confirmViewModel.loadSuggestedTotalIfNeeded(householdId: financeVM.householdId)
        }
    }

    private func processSelectedItem(_ item: PhotosPickerItem) async {
        defer { selectedItem = nil }

        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else {
                captureErrorMessage = "That photo didn't open\u{2014}try another?"
                return
            }
            await processReceiptImage(image)
        } catch {
            captureErrorMessage = error.localizedDescription
        }
    }

    private func processReceiptImage(_ image: UIImage) async {
        isProcessing = true
        captureErrorMessage = nil
        defer { isProcessing = false }

        do {
            let lines = try await ReceiptOCRService.extractText(from: image)
            let receipt = ReceiptParser.parse(lines)

            if receipt.items.isEmpty {
                captureErrorMessage = "We couldn't read lines off that\u{2014}try a sharper photo."
                return
            }

            parsedReceipt = receipt
            confirmViewModel = makeConfirmViewModel(parsedReceipt: receipt)
            wireSuccessHandler()
            if confirmViewModel.manualTotalText.isEmpty {
                await confirmViewModel.loadSuggestedTotalIfNeeded(householdId: financeVM.householdId)
            }
        } catch {
            captureErrorMessage = error.localizedDescription
        }
    }

    // MARK: - Helpers

    private func makeConfirmViewModel(parsedReceipt: ParsedReceipt? = nil) -> ReceiptConfirmationViewModel {
        if let parsedReceipt {
            return ReceiptConfirmationViewModel(
                parsedReceipt: parsedReceipt,
                pantryRepository: pantryRepository,
                householdId: financeVM.householdId,
                userId: financeVM.userId,
                userRole: userRole
            )
        } else {
            return ReceiptConfirmationViewModel(
                pantryRepository: pantryRepository,
                householdId: financeVM.householdId,
                userId: financeVM.userId,
                userRole: userRole
            )
        }
    }

    private func wireSuccessHandler() {
        confirmViewModel.onSuccess = { [dismiss, onDismiss] in
            dismiss()
            onDismiss?()
        }
    }
}
