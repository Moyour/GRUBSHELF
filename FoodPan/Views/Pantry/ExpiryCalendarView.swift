import SwiftUI

struct ExpiryCalendarView: View {
    let items: [PantryItem]
    @State private var selectedDate: Date = .now
    @State private var displayedMonth: Date = .now

    private var calendar: Calendar { Calendar.current }

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

    private var daysInMonth: [Date] {
        guard let range = calendar.range(of: .day, in: .month, for: displayedMonth) else { return [] }
        let comps = calendar.dateComponents([.year, .month], from: displayedMonth)
        return range.compactMap { day in
            calendar.date(from: DateComponents(year: comps.year, month: comps.month, day: day))
        }
    }

    private var firstWeekday: Int {
        guard let first = daysInMonth.first else { return 0 }
        return (calendar.component(.weekday, from: first) - calendar.firstWeekday + 7) % 7
    }

    private var selectedDayItems: [PantryItem] {
        let day = calendar.startOfDay(for: selectedDate)
        return itemsByDate[day] ?? []
    }

    private var monthTitle: String {
        displayedMonth.formatted(.dateTime.month(.wide).year())
    }

    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.sectionSpacing) {
                // Month header
                HStack {
                    Button {
                        withAnimation { changeMonth(by: -1) }
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.title3)
                    }

                    Spacer()

                    Text(monthTitle)
                        .font(AppFont.sectionTitle)
                        .foregroundStyle(Color.primaryText)

                    Spacer()

                    Button {
                        withAnimation { changeMonth(by: 1) }
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.title3)
                    }
                }
                .padding(.horizontal, AppSpacing.screenPadding)

                // Weekday headers
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 4) {
                    ForEach(weekdaySymbols, id: \.self) { symbol in
                        Text(symbol)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Color.secondaryText)
                    }
                }
                .padding(.horizontal, AppSpacing.screenPadding)

                // Calendar grid
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 4) {
                    ForEach(0..<firstWeekday, id: \.self) { _ in
                        Color.clear.frame(height: 44)
                    }

                    ForEach(daysInMonth, id: \.self) { date in
                        calendarDayCell(date)
                    }
                }
                .padding(.horizontal, AppSpacing.screenPadding)

                // Selected day items
                if !selectedDayItems.isEmpty {
                    VStack(alignment: .leading, spacing: AppSpacing.rowSpacing) {
                        Text("Expiring \(selectedDate.formatted(.dateTime.month(.abbreviated).day()))")
                            .font(AppFont.sectionTitle)
                            .foregroundStyle(Color.primaryText)
                            .padding(.horizontal, AppSpacing.screenPadding)

                        ForEach(selectedDayItems) { item in
                            PantryItemRow(item: item)
                                .padding(.horizontal, AppSpacing.screenPadding)
                        }
                    }
                } else {
                    Text("No items expiring on this day")
                        .font(AppFont.body)
                        .foregroundStyle(Color.secondaryText)
                        .padding(.top, AppSpacing.rowSpacing)
                }
            }
            .padding(.vertical, AppSpacing.rowSpacing)
        }
        .background(Color.appBackground)
        .navigationTitle("Expiry Calendar")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Day Cell

    private func calendarDayCell(_ date: Date) -> some View {
        let day = calendar.startOfDay(for: date)
        let isToday = calendar.isDateInToday(date)
        let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
        let count = itemsByDate[day]?.count ?? 0
        let hasExpired = itemsByDate[day]?.contains { ($0.expiryDate ?? .distantFuture) < .now } ?? false

        return Button {
            selectedDate = date
        } label: {
            VStack(spacing: 2) {
                Text("\(calendar.component(.day, from: date))")
                    .font(.system(size: 14, weight: isToday ? .bold : .regular))
                    .foregroundStyle(
                        isSelected ? .white :
                        isToday ? Color.primaryGreen :
                        Color.primaryText
                    )

                if count > 0 {
                    Circle()
                        .fill(hasExpired ? Color.errorRed : Color.warningAmber)
                        .frame(width: 6, height: 6)
                } else {
                    Circle()
                        .fill(Color.clear)
                        .frame(width: 6, height: 6)
                }
            }
            .frame(width: 36, height: 44)
            .background(
                isSelected ? Color.primaryGreen :
                isToday ? Color.primaryGreen.opacity(0.1) :
                Color.clear
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private var weekdaySymbols: [String] {
        let symbols = calendar.veryShortWeekdaySymbols
        let first = calendar.firstWeekday - 1
        return Array(symbols[first...]) + Array(symbols[..<first])
    }

    private func changeMonth(by value: Int) {
        if let newMonth = calendar.date(byAdding: .month, value: value, to: displayedMonth) {
            displayedMonth = newMonth
        }
    }
}
