import SwiftUI

struct ListingDetailView: View {
    let listing: MarketplaceListing
    let vm: MarketplaceViewModel
    @Environment(AuthManager.self) private var auth
    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteAlert = false
    @State private var currentImageIndex = 0

    private var isMyListing: Bool { listing.seller_id == auth.user?.id }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Image Gallery
                    if let images = listing.images, !images.isEmpty {
                        TabView(selection: $currentImageIndex) {
                            ForEach(images.indices, id: \.self) { idx in
                                AsyncImage(url: URL(string: images[idx])) { phase in
                                    switch phase {
                                    case .success(let img):
                                        img.resizable().scaledToFill()
                                    default:
                                        imagePlaceholder
                                    }
                                }
                                .tag(idx)
                                .clipped()
                            }
                        }
                        .tabViewStyle(.page)
                        .frame(height: 300)
                    } else {
                        imagePlaceholder.frame(height: 260)
                    }

                    VStack(alignment: .leading, spacing: EQSpacing.md) {
                        // Title & Price
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(listing.title)
                                    .font(.eqSerif(.title3, weight: .bold))
                                    .foregroundStyle(Color.eqDarkBrown)
                                HStack {
                                    EQBadge(text: listing.type.listingTypeLabel, color: Color.eqChocolate)
                                    if listing.featured == true {
                                        EQBadge(text: "Featured", color: Color.eqSandyBrown)
                                    }
                                }
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(listing.priceString)
                                    .font(.eqSerif(.title3, weight: .bold))
                                    .foregroundStyle(Color.eqSaddleBrown)
                                if listing.price_negotiable == true {
                                    Text("Negotiable")
                                        .font(.caption)
                                        .foregroundStyle(Color.eqMuted)
                                }
                            }
                        }

                        EQDivider()

                        // Details
                        if listing.type == "horse" {
                            horseDetails
                        }

                        if let desc = listing.description, !desc.isEmpty {
                            VStack(alignment: .leading, spacing: EQSpacing.xs) {
                                Text("Description")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Color.eqMuted)
                                Text(desc)
                                    .font(.body)
                                    .foregroundStyle(Color.eqDarkBrown)
                            }
                        }

                        EQDivider()

                        // Seller
                        sellerSection

                        // Contact Button
                        if !isMyListing {
                            EQPrimaryButton(title: "Contact Seller", icon: "message.fill") {
                                // Navigate to messages
                            }
                        }
                    }
                    .padding(EQSpacing.md)
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .eqNavAppearance()
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if isMyListing {
                        Button(role: .destructive) {
                            showDeleteAlert = true
                        } label: {
                            Image(systemName: "trash").foregroundStyle(.white)
                        }
                    }
                }
            }
            .alert("Remove listing?", isPresented: $showDeleteAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Remove", role: .destructive) {
                    Task {
                        try? await vm.delete(listing)
                        dismiss()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var horseDetails: some View {
        let details: [(String, String?)] = [
            ("Breed",      listing.breed),
            ("Age",        listing.age.map { "\($0) years" }),
            ("Gender",     listing.gender?.capitalized),
            ("Height",     listing.height),
            ("Discipline", listing.discipline),
            ("Location",   listing.location),
        ]
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
                        }
                        .padding(.vertical, 10)
                        EQDivider()
                    }
                }
            }
            .padding(.vertical, -8)
        }
    }

    private var sellerSection: some View {
        HStack(spacing: EQSpacing.md) {
            InitialsAvatar(text: listing.seller_name ?? "?", size: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text(listing.seller_name ?? "Seller")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.eqDarkBrown)
                if let phone = listing.seller_phone, !phone.isEmpty {
                    Text(phone)
                        .font(.caption)
                        .foregroundStyle(Color.eqMuted)
                }
            }
            Spacer()
        }
    }

    private var imagePlaceholder: some View {
        ZStack {
            LinearGradient.eqBrown
            Image(systemName: listing.type == "horse" ? "figure.equestrian.sports" : "tag.fill")
                .font(.system(size: 64))
                .foregroundStyle(.white.opacity(0.3))
        }
    }
}

// MARK: - Listing Form

struct ListingFormView: View {
    let vm: MarketplaceViewModel
    @Environment(AuthManager.self) private var auth
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var type = "horse"
    @State private var price = ""
    @State private var negotiable = false
    @State private var description = ""
    @State private var location = ""
    @State private var phone = ""
    @State private var breed = ""
    @State private var age = ""
    @State private var gender = ""
    @State private var discipline = ""
    @State private var isSaving = false
    @State private var error: String?

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
                            EQTextField(label: "Title *", placeholder: "e.g. Registered AQHA Mare", text: $title)

                            EQPickerField(
                                label: "Category",
                                selection: $type,
                                options: MarketplaceListing.listingTypes
                            )

                            HStack(spacing: EQSpacing.sm) {
                                EQTextField(label: "Price ($)", placeholder: "0", text: $price, keyboard: .numberPad)
                                    .frame(maxWidth: .infinity)
                                VStack(alignment: .leading, spacing: EQSpacing.xs) {
                                    Text("Negotiable")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(Color.eqDarkBrown)
                                    Toggle("", isOn: $negotiable)
                                        .tint(Color.eqSaddleBrown)
                                        .labelsHidden()
                                        .frame(height: 50)
                                }
                            }

                            if type == "horse" {
                                EQPickerField(
                                    label: "Breed",
                                    selection: $breed,
                                    options: [("", "Select…")] + Horse.commonBreeds.map { ($0, $0) }
                                )
                                EQTextField(label: "Age", placeholder: "e.g. 7", text: $age, keyboard: .numberPad)
                                EQPickerField(label: "Gender", selection: $gender, options: [("", "Select…")] + Horse.genders)
                                EQPickerField(
                                    label: "Discipline",
                                    selection: $discipline,
                                    options: [("", "Select…")] + Horse.disciplines.map { ($0, $0) }
                                )
                            }

                            EQTextField(label: "Location", placeholder: "City, State", text: $location, icon: "mappin")
                            EQTextField(label: "Phone", placeholder: "Optional", text: $phone, icon: "phone", keyboard: .phonePad)
                            EQTextEditor(label: "Description", placeholder: "Describe this listing…", text: $description)
                        }
                        .padding(.horizontal, EQSpacing.md)

                        EQPrimaryButton(title: isSaving ? "Posting…" : "Post Listing", isLoading: isSaving) {
                            Task { await post() }
                        }
                        .padding(.horizontal, EQSpacing.md)
                        .padding(.bottom, EQSpacing.xl)
                    }
                    .padding(.top, EQSpacing.md)
                }
            }
            .navigationTitle("New Listing")
            .navigationBarTitleDisplayMode(.inline)
            .eqNavAppearance()
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(.white)
                }
            }
        }
    }

    private func post() async {
        guard !title.isEmpty else { error = "Please enter a title."; return }
        isSaving = true
        error = nil
        let listing = MarketplaceListing(
            id: UUID().uuidString,
            title: title,
            type: type,
            price: Double(price),
            price_negotiable: negotiable,
            description: description.isEmpty ? nil : description,
            location: location.isEmpty ? nil : location,
            seller_id: auth.user?.id,
            seller_name: auth.user?.full_name,
            seller_phone: phone.isEmpty ? nil : phone,
            status: "active",
            breed: breed.isEmpty ? nil : breed,
            age: Int(age),
            gender: gender.isEmpty ? nil : gender,
            discipline: discipline.isEmpty ? nil : discipline
        )
        do {
            try await vm.create(listing)
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
        isSaving = false
    }
}
