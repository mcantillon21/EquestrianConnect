import SwiftUI

struct HorseProfileView: View {
    let horse: Horse
    let vm: HorsesViewModel
    @State private var showEditSheet = false
    @State private var showDeleteAlert = false
    @State private var selectedTab = "overview"
    @Environment(\.dismiss) private var dismiss

    private let tabs = ["overview", "health", "documents", "training", "earnings"]

    var body: some View {
        ZStack {
            Color.eqWarmWhite.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    HorseHeroHeader(horse: horse)

                    // Tab Selector
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 0) {
                            ForEach(tabs, id: \.self) { tab in
                                Button {
                                    withAnimation(.eqSnap) {
                                        selectedTab = tab
                                    }
                                    HapticFeedback.selection()
                                } label: {
                                    VStack(spacing: 6) {
                                        Text(tab.capitalized)
                                            .font(.subheadline.weight(selectedTab == tab ? .semibold : .regular))
                                            .foregroundStyle(selectedTab == tab ? Color.eqSaddleBrown : Color.eqMuted)
                                        Rectangle()
                                            .fill(selectedTab == tab ? Color.eqSaddleBrown : Color.clear)
                                            .frame(height: 2)
                                    }
                                    .padding(.horizontal, EQSpacing.md)
                                    .padding(.vertical, EQSpacing.sm)
                                }
                            }
                        }
                    }
                    .background(Color.eqWarmWhite)
                    .overlay(alignment: .bottom) {
                        EQDivider()
                    }

                    // Tab Content
                    Group {
                        switch selectedTab {
                        case "overview":   OverviewTab(horse: horse)
                        case "health":     HealthTab(horse: horse)
                        case "documents":  DocumentsTab(horse: horse)
                        case "training":   TrainingTab(horse: horse)
                        case "earnings":   EarningsTab(horse: horse)
                        default:           EmptyView()
                        }
                    }
                    .padding(.horizontal, EQSpacing.md)
                    .padding(.vertical, EQSpacing.md)
                }
            }
        }
        .navigationTitle(horse.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .eqNavAppearance()
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    showEditSheet = true
                } label: {
                    Image(systemName: "pencil")
                        .foregroundStyle(.white)
                }
                Menu {
                    Button(role: .destructive) {
                        showDeleteAlert = true
                    } label: {
                        Label("Delete Horse", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundStyle(.white)
                }
            }
        }
        .sheet(isPresented: $showEditSheet) {
            HorseFormView(vm: vm, editingHorse: horse)
        }
        .alert("Delete \(horse.name)?", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                Task {
                    try? await vm.delete(horse)
                    dismiss()
                }
            }
        } message: {
            Text("This action cannot be undone.")
        }
    }
}

// MARK: - Hero Header

private struct HorseHeroHeader: View {
    let horse: Horse

    var body: some View {
        ZStack(alignment: .bottom) {
            // Background
            Group {
                if let img = horse.profile_image, !img.isEmpty {
                    AsyncImage(url: URL(string: img)) { phase in
                        switch phase {
                        case .success(let img):
                            img.resizable().scaledToFill()
                        default:
                            LinearGradient.eqBrown
                        }
                    }
                } else {
                    LinearGradient.eqBrown
                }
            }
            .frame(height: 260)
            .clipped()

            // Gradient overlay
            LinearGradient(
                colors: [.clear, .eqDarkBrown.opacity(0.8)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 260)

            // Info overlay
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(horse.name)
                        .font(.eqSerif(.title, weight: .bold))
                        .foregroundStyle(.white)
                    if let barnName = horse.barn_name {
                        Text("\"\(barnName)\"")
                            .font(.subheadline)
                            .foregroundStyle(Color.eqSandyBrown)
                            .italic()
                    }
                }
                Spacer()
                if let disc = horse.discipline {
                    EQBadge(text: disc)
                }
            }
            .padding(EQSpacing.md)
        }
    }
}

// MARK: - Overview Tab

private struct OverviewTab: View {
    let horse: Horse

    private let fields: [(String, String?)] = []

    var body: some View {
        VStack(spacing: EQSpacing.md) {
            EQCard {
                VStack(spacing: 0) {
                    ForEach(details, id: \.0) { label, value in
                        if let v = value, !v.isEmpty {
                            HStack {
                                Text(label)
                                    .font(.subheadline)
                                    .foregroundStyle(Color.eqMuted)
                                Spacer()
                                Text(v)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(Color.eqDarkBrown)
                                    .multilineTextAlignment(.trailing)
                            }
                            .padding(.vertical, 10)
                            EQDivider()
                        }
                    }
                }
                .padding(.vertical, -8)
            }
        }
    }

    private var details: [(String, String?)] {
        [
            ("Breed",               horse.breed),
            ("Color",               horse.color),
            ("Gender",              horse.gender.map { $0.capitalized }),
            ("Date of Birth",       horse.date_of_birth?.toDisplayDate()),
            ("Age",                 horse.age.map { "\($0) years" }),
            ("Discipline",          horse.discipline),
            ("Registration #",      horse.registration_number),
            ("Owner",               horse.owner_email),
            ("Trainer",             horse.trainer_email),
        ]
    }
}

// MARK: - Health Tab

private struct HealthTab: View {
    let horse: Horse

    var body: some View {
        EmptyStateView(
            icon: "cross.case.fill",
            title: "Health Records",
            subtitle: "Vet records, farrier visits, and health notes will appear here"
        )
        .frame(height: 300)
    }
}

// MARK: - Documents Tab

private struct DocumentsTab: View {
    let horse: Horse
    @State private var documents: [HorseDocument] = []
    @State private var showAddSheet = false
    @State private var selectedDocument: HorseDocument?

    var body: some View {
        VStack(spacing: EQSpacing.md) {

            // Add Document button
            Button { showAddSheet = true } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle.fill")
                    Text("Add Document")
                        .font(.subheadline.weight(.semibold))
                }
                .foregroundStyle(Color.eqSaddleBrown)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    Color.eqSaddleBrown.opacity(0.08),
                    in: RoundedRectangle(cornerRadius: EQRadius.md, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: EQRadius.md, style: .continuous)
                        .strokeBorder(Color.eqSaddleBrown.opacity(0.25), lineWidth: 1)
                )
            }

            if documents.isEmpty {
                EmptyStateView(
                    icon: "doc.badge.plus",
                    title: "No Documents Yet",
                    subtitle: "Upload vet records, registration papers, health certificates, and more"
                )
                .frame(height: 280)
            } else {
                let grouped = Dictionary(grouping: documents) { $0.type }
                let typeOrder = HorseDocument.allTypes.map(\.value)

                ForEach(typeOrder, id: \.self) { type in
                    if let docs = grouped[type], !docs.isEmpty {
                        documentSection(type: type, docs: docs)
                    }
                }
            }
        }
        .task { loadDocuments() }
        .sheet(isPresented: $showAddSheet) {
            AddDocumentSheet(horseId: horse.id) { newDoc in
                documents.insert(newDoc, at: 0)
            }
        }
        .sheet(item: $selectedDocument) { doc in
            DocumentDetailSheet(document: doc) { updated in
                if let idx = documents.firstIndex(where: { $0.id == updated.id }) {
                    documents[idx] = updated
                }
            } onDelete: {
                documents.removeAll { $0.id == doc.id }
            }
        }
    }

    @ViewBuilder
    private func documentSection(type: String, docs: [HorseDocument]) -> some View {
        VStack(alignment: .leading, spacing: EQSpacing.xs) {
            HStack {
                Text(docs.first?.typeLabel ?? "")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.eqMuted)
                    .textCase(.uppercase)
                    .tracking(0.5)
                Spacer()
                if docs.count > 1 {
                    Text("\(docs.count)")
                        .font(.caption)
                        .foregroundStyle(Color.eqMuted)
                }
            }
            .padding(.horizontal, 4)
            .padding(.top, EQSpacing.xs)

            ForEach(docs) { doc in
                DocumentCard(document: doc) {
                    selectedDocument = doc
                }
            }
        }
    }

    private func loadDocuments() {
        #if targetEnvironment(simulator)
        documents = HorseDocument.mockDocuments(for: horse.id)
        return
        #endif
        if isDemoMode {
            documents = HorseDocument.mockDocuments(for: horse.id)
            return
        }
        Task {
            if let docs: [HorseDocument] = try? await Base44Client.shared.filter(
                entity: "HorseDocument",
                query: ["horse_id": horse.id],
                sort: "-date",
                limit: 50
            ) {
                await MainActor.run { documents = docs }
            }
        }
    }
}

// MARK: - Document Card

private struct DocumentCard: View {
    let document: HorseDocument
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            EQCard(padding: EQSpacing.sm) {
                HStack(spacing: EQSpacing.sm) {
                    // Type icon
                    ZStack {
                        RoundedRectangle(cornerRadius: EQRadius.sm, style: .continuous)
                            .fill(document.typeColor.opacity(0.12))
                            .frame(width: 42, height: 42)
                        Image(systemName: document.typeIcon)
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(document.typeColor)
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text(document.title)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Color.eqDarkBrown)
                            .lineLimit(1)
                        if let date = document.date {
                            Text(date.toDisplayDate())
                                .font(.caption)
                                .foregroundStyle(Color.eqMuted)
                        }
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.eqLightTan)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Document Detail Sheet

private struct DocumentDetailSheet: View {
    let document: HorseDocument
    let onUpdate: (HorseDocument) -> Void
    let onDelete: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteAlert = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.eqWarmWhite.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: EQSpacing.lg) {

                        // Icon + title header
                        VStack(spacing: EQSpacing.sm) {
                            ZStack {
                                RoundedRectangle(cornerRadius: EQRadius.lg, style: .continuous)
                                    .fill(document.typeColor.opacity(0.12))
                                    .frame(width: 76, height: 76)
                                Image(systemName: document.typeIcon)
                                    .font(.system(size: 34, weight: .medium))
                                    .foregroundStyle(document.typeColor)
                            }

                            Text(document.title)
                                .font(.eqSerif(.title3, weight: .bold))
                                .foregroundStyle(Color.eqDarkBrown)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, EQSpacing.md)

                            EQBadge(text: document.typeLabel)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, EQSpacing.sm)

                        // Details card
                        EQCard {
                            VStack(spacing: 0) {
                                if let date = document.date {
                                    detailRow(label: "Date", value: date.toDisplayDate())
                                    EQDivider()
                                }
                                detailRow(label: "Type", value: document.typeLabel)
                                if let uploader = document.uploaded_by {
                                    EQDivider()
                                    detailRow(label: "Added by", value: uploader)
                                }
                            }
                            .padding(.vertical, -8)
                        }

                        // Notes
                        if let notes = document.notes, !notes.isEmpty {
                            VStack(alignment: .leading, spacing: EQSpacing.xs) {
                                Text("Notes")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Color.eqMuted)
                                    .textCase(.uppercase)
                                    .tracking(0.5)
                                    .padding(.horizontal, 4)

                                EQCard {
                                    Text(notes)
                                        .font(.subheadline)
                                        .foregroundStyle(Color.eqDarkBrown)
                                        .lineSpacing(4)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                        }

                        // File button
                        VStack(spacing: EQSpacing.xs) {
                            Button {
                                if let urlString = document.file_url, let url = URL(string: urlString) {
                                    UIApplication.shared.open(url)
                                }
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "doc.viewfinder")
                                    Text(document.file_url != nil ? "View File" : "No File Attached")
                                        .font(.subheadline.weight(.semibold))
                                }
                                .foregroundStyle(document.file_url != nil ? Color.white : Color.eqMuted)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(
                                    document.file_url != nil
                                        ? AnyShapeStyle(Color.eqSaddleBrown)
                                        : AnyShapeStyle(Color.eqTaupe.opacity(0.3)),
                                    in: RoundedRectangle(cornerRadius: EQRadius.md, style: .continuous)
                                )
                            }
                            .disabled(document.file_url == nil)

                            if document.file_url == nil {
                                Text("File upload coming in a future update")
                                    .font(.caption)
                                    .foregroundStyle(Color.eqMuted)
                            }
                        }

                        // Delete
                        Button(role: .destructive) {
                            showDeleteAlert = true
                        } label: {
                            Text("Delete Document")
                                .font(.subheadline)
                                .foregroundStyle(Color.red.opacity(0.8))
                                .frame(maxWidth: .infinity)
                        }
                        .padding(.bottom, EQSpacing.lg)
                    }
                    .padding(.horizontal, EQSpacing.md)
                }
            }
            .navigationTitle("Document")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Color.eqSaddleBrown)
                }
            }
            .alert("Delete Document?", isPresented: $showDeleteAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    onDelete()
                    dismiss()
                }
            } message: {
                Text("This action cannot be undone.")
            }
        }
    }

    private func detailRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(Color.eqMuted)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color.eqDarkBrown)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 10)
    }
}

// MARK: - Add Document Sheet

private struct AddDocumentSheet: View {
    let horseId: String
    let onAdd: (HorseDocument) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedType = "vet_record"
    @State private var title = ""
    @State private var date = Date()
    @State private var includeDate = true
    @State private var notes = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Document Type") {
                    Picker("Type", selection: $selectedType) {
                        ForEach(HorseDocument.allTypes, id: \.value) { type in
                            Label(type.label, systemImage: iconFor(type.value))
                                .tag(type.value)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(Color.eqSaddleBrown)
                }

                Section("Details") {
                    TextField("Title", text: $title)
                        .autocorrectionDisabled()

                    Toggle("Include Date", isOn: $includeDate)
                        .tint(Color.eqSaddleBrown)

                    if includeDate {
                        DatePicker("Date", selection: $date, displayedComponents: .date)
                            .tint(Color.eqSaddleBrown)
                    }
                }

                Section("Notes (Optional)") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 80)
                }
            }
            .navigationTitle("Add Document")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.eqMuted)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { save() }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.eqSaddleBrown)
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func save() {
        let resolvedTitle = title.trimmingCharacters(in: .whitespaces).isEmpty
            ? (HorseDocument.allTypes.first(where: { $0.value == selectedType })?.label ?? "Document")
            : title.trimmingCharacters(in: .whitespaces)
        let doc = HorseDocument(
            id: UUID().uuidString,
            horse_id: horseId,
            title: resolvedTitle,
            type: selectedType,
            date: includeDate ? date.iso8601DateString : nil,
            notes: notes.trimmingCharacters(in: .whitespaces).isEmpty ? nil : notes.trimmingCharacters(in: .whitespaces),
            file_url: nil,
            uploaded_by: nil,
            created_date: Date().iso8601DateString
        )
        onAdd(doc)
        dismiss()
    }

    private func iconFor(_ type: String) -> String {
        HorseDocument(id: "", horse_id: "", title: "", type: type).typeIcon
    }
}

// MARK: - Training Tab

private struct TrainingTab: View {
    let horse: Horse
    @State private var logs: [TrainingLog] = []
    @State private var isLoading = false
    @State private var isTodayLogged = false
    @Environment(AuthManager.self) private var auth

    var body: some View {
        VStack(spacing: EQSpacing.md) {
            // Mark as Ridden Today
            EQCard {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Today's Training")
                            .font(.eqSerif(.subheadline, weight: .bold))
                            .foregroundStyle(Color.eqDarkBrown)
                        Text(Date().formatted("EEEE, MMM d"))
                            .font(.caption)
                            .foregroundStyle(Color.eqMuted)
                    }
                    Spacer()
                    Button {
                        Task { await toggleToday() }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: isTodayLogged ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(isTodayLogged ? Color.eqSaddleBrown : Color.eqLightTan)
                            Text(isTodayLogged ? "Ridden" : "Mark Ridden")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(isTodayLogged ? Color.eqSaddleBrown : Color.eqMuted)
                        }
                    }
                    .disabled(isLoading)
                }
            }

            if logs.isEmpty {
                EmptyStateView(
                    icon: "figure.equestrian.sports",
                    title: "No Training Logs",
                    subtitle: "Mark sessions as completed to build a training history"
                )
                .frame(height: 200)
            } else {
                VStack(spacing: EQSpacing.xs) {
                    ForEach(logs.prefix(30)) { log in
                        EQCard(padding: EQSpacing.sm) {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(Color.eqSaddleBrown)
                                Text(log.date.toDisplayDate())
                                    .font(.subheadline)
                                    .foregroundStyle(Color.eqDarkBrown)
                                Spacer()
                            }
                        }
                    }
                }
            }
        }
        .task { await loadLogs() }
    }

    private func loadLogs() async {
        isLoading = true
        do {
            logs = try await Base44Client.shared.filter(
                entity: "TrainingLog",
                query: ["horse_id": horse.id],
                sort: "-date",
                limit: 30
            )
            let today = Date().iso8601DateString
            isTodayLogged = logs.contains(where: { $0.date == today })
        } catch {}
        isLoading = false
    }

    private func toggleToday() async {
        let today = Date().iso8601DateString
        if isTodayLogged {
            if let log = logs.first(where: { $0.date == today }) {
                try? await Base44Client.shared.delete(entity: "TrainingLog", id: log.id)
                logs.removeAll { $0.date == today }
                isTodayLogged = false
            }
        } else {
            let new = TrainingLog(
                id: UUID().uuidString,
                horse_id: horse.id,
                date: today,
                user_email: auth.user?.email
            )
            if let created: TrainingLog = try? await Base44Client.shared.create(entity: "TrainingLog", data: new) {
                logs.insert(created, at: 0)
                isTodayLogged = true
            }
        }
    }
}

// MARK: - Earnings Tab

private struct EarningsTab: View {
    let horse: Horse

    var body: some View {
        VStack(spacing: EQSpacing.md) {
            if let earnings = horse.total_earnings {
                EQCard {
                    VStack(spacing: EQSpacing.sm) {
                        Text("Total Earnings")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.eqMuted)
                        Text(earnings.currencyString)
                            .font(.eqSerif(.title, weight: .bold))
                            .foregroundStyle(Color.eqDarkBrown)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, EQSpacing.sm)
                }
            }
            EmptyStateView(
                icon: "dollarsign.circle.fill",
                title: "Earnings History",
                subtitle: "Show earnings and prize money history here"
            )
            .frame(height: 200)
        }
    }
}
