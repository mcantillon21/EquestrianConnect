import SwiftUI

struct CalendarView: View {
    @Environment(AuthManager.self) private var auth
    @State private var vm = CalendarViewModel()
    @State private var showAddEvent = false
    @State private var displayedMonth = Date()
    @State private var selectedEvent: CalendarEvent? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                Color.eqWarmWhite.ignoresSafeArea()

                VStack(spacing: 0) {
                    MonthCalendarView(
                        displayedMonth: $displayedMonth,
                        selectedDate: $vm.selectedDate,
                        eventDates: vm.eventDates
                    )
                    .background(Color.eqWarmWhite)

                    EQDivider()

                    // Events for selected day
                    VStack(alignment: .leading, spacing: EQSpacing.sm) {
                        Text(vm.selectedDate.formatted("EEEE, MMMM d"))
                            .font(.eqSerif(.subheadline, weight: .bold))
                            .foregroundStyle(Color.eqDarkBrown)
                            .padding(.horizontal, EQSpacing.md)
                            .padding(.top, EQSpacing.md)

                        if vm.isLoading {
                            EQLoadingView().frame(height: 200)
                        } else if vm.eventsForSelectedDate.isEmpty {
                            Text("No events scheduled")
                                .font(.subheadline)
                                .foregroundStyle(Color.eqMuted)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, EQSpacing.xxl)
                        } else {
                            ScrollView {
                                LazyVStack(spacing: EQSpacing.sm) {
                                    ForEach(vm.eventsForSelectedDate) { event in
                                        EventCard(event: event) {
                                            selectedEvent = event
                                        }
                                        .padding(.horizontal, EQSpacing.md)
                                    }
                                }
                                .padding(.bottom, EQSpacing.xxl)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                }
            }
            .navigationTitle("Calendar")
            .eqNavAppearance()
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAddEvent = true
                    } label: {
                        Image(systemName: "plus")
                            .foregroundStyle(.white)
                    }
                }
            }
            .sheet(isPresented: $showAddEvent) {
                EventFormView(vm: vm, defaultDate: vm.selectedDate)
            }
            .sheet(item: $selectedEvent) { event in
                EventDetailView(event: event, vm: vm)
            }
            .task {
                guard let user = auth.user else { return }
                await vm.load(userEmail: user.email)
            }
            .refreshable {
                guard let user = auth.user else { return }
                await vm.load(userEmail: user.email)
            }
        }
    }
}

// MARK: - Month Calendar

struct MonthCalendarView: View {
    @Binding var displayedMonth: Date
    @Binding var selectedDate: Date
    let eventDates: Set<String>

    private let calendar = Calendar.current
    private let dayLabels = ["Su","Mo","Tu","We","Th","Fr","Sa"]
    private let columns = Array(repeating: GridItem(.flexible()), count: 7)

    var body: some View {
        VStack(spacing: EQSpacing.sm) {
            // Month header
            HStack {
                Button {
                    displayedMonth = calendar.date(byAdding: .month, value: -1, to: displayedMonth)!
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color.eqSaddleBrown)
                }

                Spacer()
                Text(displayedMonth.formatted("MMMM yyyy"))
                    .font(.eqSerif(.headline, weight: .bold))
                    .foregroundStyle(Color.eqDarkBrown)
                Spacer()

                Button {
                    displayedMonth = calendar.date(byAdding: .month, value: 1, to: displayedMonth)!
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color.eqSaddleBrown)
                }
            }
            .padding(.horizontal, EQSpacing.md)
            .padding(.top, EQSpacing.md)

            // Day labels
            HStack(spacing: 0) {
                ForEach(dayLabels, id: \.self) { d in
                    Text(d)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.eqMuted)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, EQSpacing.sm)

            // Days Grid
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(daysInMonth(), id: \.self) { date in
                    if let date {
                        DayCell(
                            date: date,
                            isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
                            isToday: calendar.isDateInToday(date),
                            hasEvent: eventDates.contains(date.iso8601DateString)
                        ) {
                            selectedDate = date
                        }
                    } else {
                        Color.clear.frame(height: 40)
                    }
                }
            }
            .padding(.horizontal, EQSpacing.sm)
            .padding(.bottom, EQSpacing.sm)
        }
    }

    private func daysInMonth() -> [Date?] {
        let comps = calendar.dateComponents([.year, .month], from: displayedMonth)
        guard let start = calendar.date(from: comps),
              let range = calendar.range(of: .day, in: .month, for: start) else { return [] }

        let weekday = calendar.component(.weekday, from: start)
        let leading = Array(repeating: Optional<Date>.none, count: weekday - 1)
        let days = range.map { d -> Date? in
            calendar.date(byAdding: .day, value: d - 1, to: start)
        }
        return leading + days
    }
}

// MARK: - Day Cell

private struct DayCell: View {
    let date: Date
    let isSelected: Bool
    let isToday: Bool
    let hasEvent: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack {
                if isSelected {
                    Circle()
                        .fill(Color.eqSaddleBrown)
                        .padding(2)
                } else if isToday {
                    Circle()
                        .strokeBorder(Color.eqSaddleBrown, lineWidth: 1.5)
                        .padding(2)
                }

                VStack(spacing: 2) {
                    Text("\(Calendar.current.component(.day, from: date))")
                        .font(.system(size: 14, weight: isToday || isSelected ? .bold : .regular))
                        .foregroundStyle(isSelected ? .white : (isToday ? Color.eqSaddleBrown : Color.eqDarkBrown))

                    if hasEvent {
                        Circle()
                            .fill(isSelected ? Color.white.opacity(0.7) : Color.eqChocolate)
                            .frame(width: 4, height: 4)
                    }
                }
            }
            .frame(height: 40)
        }
    }
}

// MARK: - Event Card

private struct EventCard: View {
    let event: CalendarEvent
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(event.type.eventTypeColor)
                    .frame(width: 3, height: 36)

                VStack(alignment: .leading, spacing: 3) {
                    Text(event.title)
                        .font(.eqFont(15, weight: .semibold))
                        .foregroundStyle(Color.eqInk)
                    HStack(spacing: EQSpacing.xs) {
                        Text(event.type.eventTypeLabel)
                            .font(.eqFont(12, weight: .regular))
                            .foregroundStyle(event.type.eventTypeColor)
                        if let loc = event.location, !loc.isEmpty {
                            Text("·").font(.eqFont(12)).foregroundStyle(Color.eqMuted)
                            Text(loc)
                                .font(.eqFont(12, weight: .regular))
                                .foregroundStyle(Color.eqMuted)
                                .lineLimit(1)
                        }
                    }
                }

                Spacer()

                if !(event.all_day ?? false) {
                    Text(event.start_date.toDisplayDate(format: "h:mm a"))
                        .font(.eqFont(13, weight: .medium))
                        .foregroundStyle(Color.eqMuted)
                } else {
                    Text("All day")
                        .font(.eqFont(12, weight: .regular))
                        .foregroundStyle(Color.eqMuted)
                }
            }
            .padding(.horizontal, EQSpacing.md)
            .padding(.vertical, 12)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: EQRadius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: EQRadius.md, style: .continuous)
                    .strokeBorder(Color.eqTaupe.opacity(0.5), lineWidth: 1)
            )
        }
        .buttonStyle(.eqScale)
    }
}
