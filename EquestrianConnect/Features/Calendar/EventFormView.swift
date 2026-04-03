import SwiftUI

struct EventFormView: View {
    let vm: CalendarViewModel
    var editingEvent: CalendarEvent? = nil
    var defaultDate: Date = Date()
    @Environment(AuthManager.self) private var auth
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var type = "training"
    @State private var startDate = Date()
    @State private var endDate = Date()
    @State private var allDay = false
    @State private var location = ""
    @State private var notes = ""
    @State private var isRecurring = false
    @State private var recurrenceFreq = "weekly"
    @State private var recurrenceCount = 4
    @State private var isSaving = false
    @State private var error: String?

    private var isEditing: Bool { editingEvent != nil }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.eqWarmWhite.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: EQSpacing.md) {
                        if let err = error {
                            ErrorBanner(message: err) { error = nil }
                        }

                        VStack(spacing: EQSpacing.md) {
                            EQTextField(label: "Event Title *", placeholder: "e.g. Vet Check-up", text: $title)

                            EQPickerField(
                                label: "Event Type",
                                selection: $type,
                                options: CalendarEvent.eventTypes,
                                icon: "tag"
                            )

                            VStack(alignment: .leading, spacing: EQSpacing.xs) {
                                Toggle("All Day", isOn: $allDay)
                                    .font(.subheadline.weight(.medium))
                                    .tint(Color.eqSaddleBrown)
                            }

                            VStack(alignment: .leading, spacing: EQSpacing.xs) {
                                Text("Start Date")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Color.eqDarkBrown)
                                DatePicker("", selection: $startDate,
                                           displayedComponents: allDay ? [.date] : [.date, .hourAndMinute])
                                    .datePickerStyle(.compact)
                                    .tint(Color.eqSaddleBrown)
                                    .labelsHidden()
                            }

                            if !allDay {
                                VStack(alignment: .leading, spacing: EQSpacing.xs) {
                                    Text("End Date")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(Color.eqDarkBrown)
                                    DatePicker("", selection: $endDate,
                                               displayedComponents: [.date, .hourAndMinute])
                                        .datePickerStyle(.compact)
                                        .tint(Color.eqSaddleBrown)
                                        .labelsHidden()
                                }
                            }

                            EQTextField(label: "Location", placeholder: "Optional", text: $location,
                                        icon: "mappin")

                            EQTextEditor(label: "Notes", placeholder: "Add notes…", text: $notes)

                            // Recurring
                            VStack(alignment: .leading, spacing: EQSpacing.sm) {
                                Toggle("Recurring Event", isOn: $isRecurring)
                                    .font(.subheadline.weight(.medium))
                                    .tint(Color.eqSaddleBrown)

                                if isRecurring {
                                    EQPickerField(
                                        label: "Frequency",
                                        selection: $recurrenceFreq,
                                        options: CalendarEvent.recurrenceOptions
                                    )
                                    VStack(alignment: .leading, spacing: EQSpacing.xs) {
                                        Text("Repeat Count")
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(Color.eqDarkBrown)
                                        Stepper("\(recurrenceCount) times", value: $recurrenceCount, in: 2...52)
                                            .font(.subheadline)
                                            .foregroundStyle(Color.eqDarkBrown)
                                    }
                                }
                            }
                            .padding(EQSpacing.md)
                            .background(Color.eqCream, in: RoundedRectangle(cornerRadius: EQRadius.sm))
                        }
                        .padding(.horizontal, EQSpacing.md)

                        EQPrimaryButton(
                            title: isSaving ? "Saving…" : (isEditing ? "Save Changes" : "Add Event"),
                            isLoading: isSaving
                        ) {
                            Task { await save() }
                        }
                        .padding(.horizontal, EQSpacing.md)
                        .padding(.bottom, EQSpacing.xl)
                    }
                    .padding(.top, EQSpacing.md)
                }
            }
            .navigationTitle(isEditing ? "Edit Event" : "New Event")
            .navigationBarTitleDisplayMode(.inline)
            .eqNavAppearance()
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(.white)
                }
            }
            .onAppear { prefill() }
        }
    }

    private func prefill() {
        if let e = editingEvent {
            title = e.title
            type = e.type
            startDate = e.start_date.toDate() ?? Date()
            endDate = e.end_date?.toDate() ?? Date()
            allDay = e.all_day ?? false
            location = e.location ?? ""
            notes = e.description ?? ""
            isRecurring = e.is_recurring ?? false
            recurrenceFreq = e.recurrence_frequency ?? "weekly"
            recurrenceCount = e.recurrence_count ?? 4
        } else {
            startDate = defaultDate
            endDate = defaultDate.addingTimeInterval(3600)
        }
    }

    private func save() async {
        guard !title.isEmpty else {
            error = "Please enter an event title."
            return
        }
        isSaving = true
        error = nil
        let event = CalendarEvent(
            id: editingEvent?.id ?? UUID().uuidString,
            title: title,
            type: type,
            start_date: startDate.iso8601String,
            end_date: allDay ? nil : endDate.iso8601String,
            all_day: allDay,
            location: location.isEmpty ? nil : location,
            description: notes.isEmpty ? nil : notes,
            user_id: auth.user?.id,
            is_recurring: isRecurring,
            recurrence_frequency: isRecurring ? recurrenceFreq : nil,
            recurrence_count: isRecurring ? recurrenceCount : nil
        )
        do {
            if isEditing {
                try await vm.updateEvent(event)
            } else {
                try await vm.createEvent(event)
            }
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
        isSaving = false
    }
}

// MARK: - Event Detail View

struct EventDetailView: View {
    let event: CalendarEvent
    let vm: CalendarViewModel
    @State private var showEdit = false
    @State private var showDeleteAlert = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.eqWarmWhite.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: EQSpacing.md) {
                        // Type Banner
                        HStack {
                            Image(systemName: event.type.eventTypeIcon)
                                .font(.title2)
                                .foregroundStyle(event.type.eventTypeColor)
                            Text(event.type.eventTypeLabel)
                                .font(.eqSerif(.title3, weight: .bold))
                                .foregroundStyle(event.type.eventTypeColor)
                            Spacer()
                        }
                        .padding(EQSpacing.md)
                        .background(event.type.eventTypeColor.opacity(0.1),
                                    in: RoundedRectangle(cornerRadius: EQRadius.md))

                        EQCard {
                            VStack(spacing: 0) {
                                detailRow("Date", event.start_date.toDisplayDate(format: "EEEE, MMMM d, yyyy"))
                                EQDivider()
                                if !(event.all_day ?? false) {
                                    detailRow("Time", event.start_date.toDisplayDate(format: "h:mm a"))
                                    EQDivider()
                                }
                                if let loc = event.location, !loc.isEmpty {
                                    detailRow("Location", loc)
                                    EQDivider()
                                }
                                if let freq = event.recurrence_frequency {
                                    detailRow("Repeats", freq.capitalized)
                                    EQDivider()
                                }
                            }
                            .padding(.vertical, -8)
                        }

                        if let desc = event.description, !desc.isEmpty {
                            VStack(alignment: .leading, spacing: EQSpacing.xs) {
                                Text("Notes")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Color.eqMuted)
                                Text(desc)
                                    .font(.body)
                                    .foregroundStyle(Color.eqDarkBrown)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(EQSpacing.md)
                            .background(Color.eqCream, in: RoundedRectangle(cornerRadius: EQRadius.md))
                        }

                        Spacer()
                    }
                    .padding(EQSpacing.md)
                }
            }
            .navigationTitle(event.title)
            .navigationBarTitleDisplayMode(.inline)
            .eqNavAppearance()
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        showEdit = true
                    } label: {
                        Image(systemName: "pencil").foregroundStyle(.white)
                    }
                    Button {
                        showDeleteAlert = true
                    } label: {
                        Image(systemName: "trash").foregroundStyle(.white)
                    }
                }
            }
            .sheet(isPresented: $showEdit) {
                EventFormView(vm: vm, editingEvent: event)
            }
            .alert("Delete event?", isPresented: $showDeleteAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    Task {
                        try? await vm.deleteEvent(event)
                        dismiss()
                    }
                }
            }
        }
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(Color.eqMuted)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color.eqDarkBrown)
        }
        .padding(.vertical, 10)
    }
}
