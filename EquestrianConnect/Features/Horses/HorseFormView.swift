import SwiftUI
import PhotosUI

struct HorseFormView: View {
    let vm: HorsesViewModel
    var editingHorse: Horse? = nil
    @Environment(AuthManager.self) private var auth
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var barnName = ""
    @State private var breed = ""
    @State private var color = ""
    @State private var gender = ""
    @State private var discipline = ""
    @State private var dateOfBirth = Date()
    @State private var hasDOB = false
    @State private var registrationNumber = ""
    @State private var trainerEmail = ""
    @State private var ownerEmail = ""
    @State private var photoItem: PhotosPickerItem? = nil
    @State private var selectedImageData: Data? = nil
    @State private var uploadedImageURL: String? = nil
    @State private var isUploading = false
    @State private var isSaving = false
    @State private var error: String?

    @State private var registrySearch = ""
    @State private var registryMatches: [HorseRegistryEntry] = []
    @State private var registryPrefilled = false

    private var isEditing: Bool { editingHorse != nil }
    private var title: String { isEditing ? "Edit Horse" : "Add Horse" }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.eqWarmWhite.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: EQSpacing.md) {
                        // Photo Picker
                        PhotoPickerSection(
                            photoItem: $photoItem,
                            selectedImageData: $selectedImageData,
                            uploadedURL: uploadedImageURL ?? editingHorse?.profile_image,
                            isUploading: isUploading
                        )
                        .onChange(of: photoItem) { _, newItem in
                            Task { await handlePhotoSelection(newItem) }
                        }

                        if let err = error {
                            ErrorBanner(message: err) { error = nil }
                        }

                        VStack(spacing: EQSpacing.md) {
                            if !isEditing {
                                registrySection
                            }

                            EQTextField(label: "Name *", placeholder: "e.g. Thunderbolt", text: $name)
                            EQTextField(label: "Barn Name / Nickname", placeholder: "e.g. Thunder", text: $barnName)

                            EQPickerField(
                                label: "Breed",
                                selection: $breed,
                                options: [("", "Select breed…")] + Horse.commonBreeds.map { ($0, $0) }
                            )

                            EQTextField(label: "Color", placeholder: "e.g. Bay", text: $color)

                            EQPickerField(
                                label: "Gender",
                                selection: $gender,
                                options: [("", "Select…")] + Horse.genders
                            )

                            EQPickerField(
                                label: "Discipline",
                                selection: $discipline,
                                options: [("", "Select…")] + Horse.disciplines.map { ($0, $0) }
                            )

                            VStack(alignment: .leading, spacing: EQSpacing.xs) {
                                Toggle(isOn: $hasDOB) {
                                    Text("Date of Birth")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(Color.eqDarkBrown)
                                }
                                .tint(Color.eqSaddleBrown)
                                if hasDOB {
                                    DatePicker("", selection: $dateOfBirth, displayedComponents: .date)
                                        .datePickerStyle(.compact)
                                        .tint(Color.eqSaddleBrown)
                                }
                            }

                            EQTextField(
                                label: "Registration Number",
                                placeholder: "Optional",
                                text: $registrationNumber
                            )

                            if auth.user?.isOwner == true {
                                EQTextField(
                                    label: "Trainer Email",
                                    placeholder: "trainer@barn.com",
                                    text: $trainerEmail,
                                    keyboard: .emailAddress
                                )
                                .textInputAutocapitalization(.never)
                            } else if auth.user?.isTrainer == true {
                                EQTextField(
                                    label: "Owner Email",
                                    placeholder: "owner@barn.com",
                                    text: $ownerEmail,
                                    keyboard: .emailAddress
                                )
                                .textInputAutocapitalization(.never)
                            }
                        }
                        .padding(.horizontal, EQSpacing.md)

                        EQPrimaryButton(title: isSaving ? "Saving…" : title, isLoading: isSaving) {
                            Task { await save() }
                        }
                        .padding(.horizontal, EQSpacing.md)
                        .padding(.bottom, EQSpacing.xl)
                    }
                    .padding(.top, EQSpacing.md)
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .eqNavAppearance()
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(.white)
                }
            }
            .onAppear {
                prefill()
                HorseRegistry.shared.loadIfNeeded()
            }
        }
    }

    // MARK: - Registry autocomplete

    private var registrySection: some View {
        VStack(alignment: .leading, spacing: EQSpacing.xs) {
            EQTextField(
                label: "Search Registry",
                placeholder: "NCHA — find by name",
                text: $registrySearch,
                icon: "magnifyingglass"
            )
            .textInputAutocapitalization(.words)
            .onChange(of: registrySearch) { _, q in
                registryMatches = HorseRegistry.shared.search(q)
            }

            if registryPrefilled {
                HStack(spacing: EQSpacing.xs) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.eqSaddleBrown)
                    Text("Prefilled from NCHA registry — edit anything below.")
                        .font(.caption)
                        .foregroundStyle(Color.eqMuted)
                }
                .padding(.horizontal, EQSpacing.xs)
            }

            if !registryMatches.isEmpty {
                VStack(spacing: 0) {
                    ForEach(Array(registryMatches.enumerated()), id: \.element.id) { idx, entry in
                        Button {
                            applyRegistry(entry)
                        } label: {
                            HStack(alignment: .center, spacing: EQSpacing.sm) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(entry.name)
                                        .font(.eqFont(15, weight: .semibold))
                                        .foregroundStyle(Color.eqInk)
                                        .lineLimit(1)
                                    Text(entry.subtitle)
                                        .font(.eqFont(12))
                                        .foregroundStyle(Color.eqMuted)
                                        .lineLimit(1)
                                }
                                Spacer()
                                Image(systemName: "arrow.up.left")
                                    .font(.caption)
                                    .foregroundStyle(Color.eqTaupe)
                            }
                            .padding(.horizontal, EQSpacing.md)
                            .padding(.vertical, 10)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        if idx != registryMatches.count - 1 {
                            EQDivider()
                        }
                    }
                }
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: EQRadius.sm, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: EQRadius.sm, style: .continuous)
                        .strokeBorder(Color.eqLightTan, lineWidth: 1)
                )
            }
        }
    }

    private func applyRegistry(_ entry: HorseRegistryEntry) {
        name = entry.name.capitalized
        gender = entry.genderValue
        registrationNumber = entry.nchaNumber
        if let iso = entry.dateOfBirthISO, let dob = iso.toDate() {
            dateOfBirth = dob
            hasDOB = true
        }
        registrySearch = ""
        registryMatches = []
        registryPrefilled = true
    }

    private func prefill() {
        guard let h = editingHorse else { return }
        name   = h.name
        barnName = h.barn_name ?? ""
        breed  = h.breed ?? ""
        color  = h.color ?? ""
        gender = h.gender ?? ""
        discipline = h.discipline ?? ""
        registrationNumber = h.registration_number ?? ""
        trainerEmail = h.trainer_id ?? ""
        ownerEmail = h.owner_id ?? ""
        uploadedImageURL = h.profile_image
        if let dob = h.date_of_birth?.toDate() {
            dateOfBirth = dob
            hasDOB = true
        }
    }

    private func handlePhotoSelection(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        guard let data = try? await item.loadTransferable(type: Data.self) else { return }
        selectedImageData = data
        isUploading = true
        do {
            uploadedImageURL = try await SupabaseClient.shared.uploadFile(imageData: data)
        } catch {
            self.error = "Image upload failed: \(error.localizedDescription)"
        }
        isUploading = false
    }

    private func save() async {
        guard !name.isEmpty else {
            error = "Please enter the horse's name."
            return
        }
        isSaving = true
        error = nil
        let id = editingHorse?.id ?? UUID().uuidString
        var horse = Horse(
            id: id,
            name: name,
            barn_name: barnName.isEmpty ? nil : barnName,
            breed: breed.isEmpty ? nil : breed,
            color: color.isEmpty ? nil : color,
            date_of_birth: hasDOB ? dateOfBirth.iso8601DateString : nil,
            gender: gender.isEmpty ? nil : gender,
            registration_number: registrationNumber.isEmpty ? nil : registrationNumber,
            discipline: discipline.isEmpty ? nil : discipline,
            owner_id: editingHorse?.owner_id ?? (auth.user?.isTrainer == true ? (ownerEmail.isEmpty ? nil : ownerEmail) : auth.user?.id),
            trainer_id: editingHorse?.trainer_id ?? (auth.user?.isTrainer == true ? auth.user?.id : (trainerEmail.isEmpty ? nil : trainerEmail)),
            profile_image: uploadedImageURL ?? editingHorse?.profile_image,
            total_earnings: editingHorse?.total_earnings
        )

        do {
            if isEditing {
                try await vm.update(horse)
            } else {
                try await vm.create(horse)
            }
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
        isSaving = false
    }
}

// MARK: - Photo Picker Section

private struct PhotoPickerSection: View {
    @Binding var photoItem: PhotosPickerItem?
    @Binding var selectedImageData: Data?
    var uploadedURL: String?
    var isUploading: Bool

    var body: some View {
        ZStack {
            // Display
            Group {
                if let data = selectedImageData, let uiImg = UIImage(data: data) {
                    Image(uiImage: uiImg)
                        .resizable()
                        .scaledToFill()
                } else if let url = uploadedURL, !url.isEmpty {
                    AsyncImage(url: URL(string: url)) { phase in
                        switch phase {
                        case .success(let img): img.resizable().scaledToFill()
                        default: horsePlaceholder
                        }
                    }
                } else {
                    horsePlaceholder
                }
            }
            .frame(width: 110, height: 110)
            .clipShape(Circle())

            if isUploading {
                Circle()
                    .fill(Color.black.opacity(0.4))
                    .frame(width: 110, height: 110)
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(.white)
            }

            // Edit badge
            PhotosPicker(selection: $photoItem, matching: .images) {
                ZStack {
                    Circle()
                        .fill(Color.eqSaddleBrown)
                        .frame(width: 32, height: 32)
                    Image(systemName: "camera.fill")
                        .font(.caption)
                        .foregroundStyle(.white)
                }
            }
            .offset(x: 36, y: 36)
        }
        .padding(.top, EQSpacing.md)
    }

    private var horsePlaceholder: some View {
        ZStack {
            Circle().fill(Color.eqMutedBrown)
            Image(systemName: "figure.equestrian.sports")
                .font(.largeTitle)
                .foregroundStyle(Color.eqSaddleBrown)
        }
    }
}
