import SwiftUI

struct ExpiryCalendarView: View {
    let items: [PantryItem]
    var householdId: UUID?
    var userId: UUID?
    var userRole: UserRole = .member

    @State private var selectedDate: Date = .now
    @State private var itemToEdit: PantryItem?
    /// Any date within the visible week; week boundaries come from `dateInterval(of: .weekOfYear, ...)`.
    @State private var weekContainingDate: Date = .now

    private var calendar: Calendar { Calendar.current }

    private var weekStart: Date {
        calendar.dateInterval(of: .weekOfYear, for: weekContainingDate)?.start ?? weekContainingDate
    }

    private var daysInWeek: [Date] {
        (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: weekStart) }
    }

    private var expiringItems: [PantryItem] {
        items.filter { $0.expiryDate != nil && !$0.archived }
    }

    private var itemsByDate: [Date: [PantryItem]] {
        var grouped: [Date: [PantryItem]] = [:]
        for item in expiringItems {
            guard let expiry = item.expiryDate else { continue }
            let day = calendar.startOfDay(for: expiry)
            grouped[day, default: []].append(item)
        }
        return grouped
    }

    private var selectedDayItems: [PantryItem] {
        let day = calendar.startOfDay(for: selectedDate)
        return itemsByDate[day] ?? []
    }

    private var weekTitle: String {
        guard let end = calendar.date(byAdding: .day, value: 6, to: weekStart) else {
            return weekStart.formatted(.dateTime.month(.abbreviated).day().year())
        }
        let sameMonth = calendar.isDate(weekStart, equalTo: end, toGranularity: .month)
        if sameMonth {
            let y = calendar.component(.year, from: weekStart)
            let m = weekStart.formatted(.dateTime.month(.abbreviated))
            let d0 = calendar.component(.day, from: weekStart)
            let d1 = calendar.component(.day, from: end)
            return "\(m) \(d0)–\(d1), \(y)"
        }
        return "\(weekStart.formatted(.dateTime.month(.abbreviated).day())) – \(end.formatted(.dateTime.month(.abbreviated).day().year()))"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.sectionSpacing) {
                VStack(alignment: .leading, spacing: AppSpacing.microGap) {
                    HStack {
                        Spacer()
                        Text(weekTitle)
                            .font(BrandFont.medium(13))
                            .foregroundStyle(.gsTextSecondary)
                        Spacer()
                        if !calendar.isDateInToday(selectedDate) {
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedDate = .now
                                    weekContainingDate = .now
                                }
                            } label: {
                                Text("Today")
                                    .font(BrandFont.semiBold(13))
                                    .foregroundStyle(.gsBrandPrimary)
                            }
                            .buttonStyle(.plain)
                            .transition(.opacity)
                        }
                    }

                    // Single-row week strip
                    HStack(spacing: AppSpacing.microGap) {
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) { changeWeek(by: -1) }
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(BrandSymbolFont.symbol(16))
                                .foregroundStyle(.gsTextPrimary)
                                .frame(width: AppSpacing.chevronTouchWidth, height: AppSpacing.chevronTouchHeight)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Previous week")

                        HStack(spacing: 0) {
                            ForEach(daysInWeek, id: \.self) { date in
                                compactWeekDayCell(date)
                            }
                        }
                        .padding(.vertical, AppSpacing.compactGap)
                        .padding(.horizontal, AppSpacing.microGap)
                        .frame(maxWidth: .infinity)
                        .background(Color.gsSurface)
                        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.badgeCornerRadius, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: AppSpacing.badgeCornerRadius, style: .continuous)
                                .strokeBorder(Color.gsBorder.opacity(0.45), lineWidth: 0.5)
                        )

                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) { changeWeek(by: 1) }
                        } label: {
                            Image(systemName: "chevron.right")
                                .font(BrandSymbolFont.symbol(16))
                                .foregroundStyle(.gsTextPrimary)
                                .frame(width: AppSpacing.chevronTouchWidth, height: AppSpacing.chevronTouchHeight)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Next week")
                    }
                }
                .padding(.horizontal, AppSpacing.screenPadding)

                // Selected day items
                if !selectedDayItems.isEmpty {
                    VStack(alignment: .leading, spacing: AppSpacing.rowSpacing) {
                        Text("Expiring \(selectedDate.formatted(.dateTime.month(.abbreviated).day()))")
                            .font(BrandFont.semiBold(18))
                            .foregroundStyle(.gsTextPrimary)
                            .padding(.horizontal, AppSpacing.screenPadding)

                        ForEach(selectedDayItems) { item in
                            PantryItemRow(
                                item: item,
                                onTapEdit: canEditItems ? { itemToEdit = item } : nil
                            )
                            .padding(.horizontal, AppSpacing.screenPadding)
                        }
                    }
                } else {
                    Text("No items expiring on this day")
                        .font(BrandFont.regular(17))
                        .foregroundStyle(.gsTextSecondary)
                        .padding(.top, AppSpacing.rowSpacing)
                }
            }
            .padding(.vertical, AppSpacing.rowSpacing)
        }
        .background(.gsBackground)
        .navigationTitle("Expiry Calendar")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $itemToEdit) { item in
            if let householdId, let userId {
                AddEditPantryItemView(
                    viewModel: AddEditPantryItemViewModel(
                        repository: SupabasePantryRepository(),
                        householdId: householdId,
                        userId: userId,
                        userRole: userRole,
                        existingItem: item
                    )
                )
            }
        }
    }

    private var canEditItems: Bool {
        householdId != nil && userId != nil
    }

    // MARK: - Day Cell

    private func compactWeekDayCell(_ date: Date) -> some View {
        let day = calendar.startOfDay(for: date)
        let isToday = calendar.isDateInToday(date)
        let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
        let count = itemsByDate[day]?.count ?? 0
        let hasExpired = itemsByDate[day]?.contains { ($0.expiryDate ?? .distantFuture) < .now } ?? false
        let weekdayIndex = calendar.component(.weekday, from: date) - 1
        let weekdayLetter = calendar.veryShortWeekdaySymbols[weekdayIndex]

        return Button {
            selectedDate = date
            weekContainingDate = date
        } label: {
            VStack(spacing: AppSpacing.microGap) {
                Text(weekdayLetter)
                    .font(BrandFont.medium(10))
                    .foregroundStyle(isSelected ? Color.gsTextInverse.opacity(0.92) : .gsTextSecondary)

                Text("\(calendar.component(.day, from: date))")
                    .font(isToday ? BrandFont.bold(12) : BrandFont.medium(12))
                    .foregroundStyle(
                        isSelected ? .gsTextInverse :
                        isToday ? .gsBrandPrimary :
                        .gsTextPrimary
                    )

                Circle()
                    .fill(dotColor(count: count, hasExpired: hasExpired, isSelected: isSelected))
                    .frame(width: AppSpacing.dotSize, height: AppSpacing.dotSize)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppSpacing.microGap)
            .background(
                RoundedRectangle(cornerRadius: AppSpacing.cellRadius, style: .continuous)
                    .fill(isSelected ? Color.gsBrandPrimary : (isToday ? Color.gsBrandPrimary.opacity(0.12) : Color.clear))
            )
        }
        .buttonStyle(.plain)
    }

    private func dotColor(count: Int, hasExpired: Bool, isSelected: Bool) -> Color {
        if count == 0 { return .clear }
        if isSelected {
            return hasExpired ? Color.gsTextInverse.opacity(0.65) : Color.gsTextInverse.opacity(0.9)
        }
        return hasExpired ? .gsTextSecondary : .gsBrandPrimary
    }

    // MARK: - Helpers

    private func changeWeek(by delta: Int) {
        let start = weekStart
        guard let newStart = calendar.date(byAdding: .day, value: delta * 7, to: start) else { return }
        let selectedDay = calendar.startOfDay(for: selectedDate)
        let dayOffset = calendar.dateComponents([.day], from: start, to: selectedDay).day ?? 0
        let clamped = min(max(dayOffset, 0), 6)
        weekContainingDate = newStart
        selectedDate = calendar.date(byAdding: .day, value: clamped, to: newStart) ?? newStart
    }
}
