import SwiftUI

struct MarketplaceView: View {
    @State private var vm = MarketplaceViewModel()
    @State private var showAddSheet = false
    @State private var selectedListing: MarketplaceListing?

    private let typeFilters: [(String, String)] = [
        ("", "All"), ("horse", "Horses"), ("tack", "Tack"),
        ("equipment", "Equipment"), ("trailer", "Trailers")
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                Color.eqWarmWhite.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Filter Pills
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: EQSpacing.sm) {
                            ForEach(typeFilters, id: \.0) { value, label in
                                FilterPill(
                                    label: label,
                                    isSelected: vm.selectedType == value
                                ) { vm.selectedType = value }
                            }
                        }
                        .padding(.horizontal, EQSpacing.md)
                        .padding(.vertical, EQSpacing.sm)
                    }

                    EQDivider()

                    if vm.isLoading {
                        EQLoadingView()
                    } else if vm.filtered.isEmpty {
                        EmptyStateView(
                            icon: "tag.fill",
                            title: "No Listings",
                            subtitle: vm.searchText.isEmpty ? "Be the first to post a listing." : "No listings match your search.",
                            actionTitle: vm.searchText.isEmpty ? "Post Listing" : nil,
                            action: vm.searchText.isEmpty ? { showAddSheet = true } : nil
                        )
                    } else {
                        ScrollView {
                            LazyVGrid(
                                columns: [GridItem(.flexible()), GridItem(.flexible())],
                                spacing: EQSpacing.sm
                            ) {
                                ForEach(vm.filtered) { listing in
                                    ListingCard(listing: listing) {
                                        selectedListing = listing
                                    }
                                }
                            }
                            .padding(EQSpacing.md)
                        }
                    }
                }
            }
            .navigationTitle("Marketplace")
            .eqNavAppearance()
            .searchable(text: $vm.searchText, prompt: "Search listings…")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                            .foregroundStyle(.white)
                    }
                }
            }
            .sheet(isPresented: $showAddSheet) {
                ListingFormView(vm: vm)
            }
            .sheet(item: $selectedListing) { listing in
                ListingDetailView(listing: listing, vm: vm)
            }
            .task { await vm.load() }
            .refreshable { await vm.load() }
        }
    }
}

// MARK: - Filter Pill

private struct FilterPill: View {
    let label: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(label)
                .font(.subheadline.weight(isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? .white : Color.eqSaddleBrown)
                .padding(.horizontal, EQSpacing.md)
                .padding(.vertical, 6)
                .background(
                    isSelected ? AnyShapeStyle(Color.eqSaddleBrown) : AnyShapeStyle(Color.eqMutedBrown),
                    in: Capsule()
                )
        }
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}

// MARK: - Listing Card

private struct ListingCard: View {
    let listing: MarketplaceListing
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                // Image
                Group {
                    if let img = listing.firstImage, !img.isEmpty {
                        AsyncImage(url: URL(string: img)) { phase in
                            switch phase {
                            case .success(let img):
                                img.resizable().scaledToFill()
                            default:
                                listingPlaceholder
                            }
                        }
                    } else {
                        listingPlaceholder
                    }
                }
                .frame(height: 130)
                .clipped()

                // Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(listing.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.eqDarkBrown)
                        .lineLimit(2)
                    Text(listing.priceString)
                        .font(.eqSerif(.subheadline, weight: .bold))
                        .foregroundStyle(Color.eqSaddleBrown)
                    HStack {
                        EQBadge(text: listing.type.listingTypeLabel, color: Color.eqChocolate)
                        Spacer()
                        if let loc = listing.location, !loc.isEmpty {
                            Text(loc)
                                .font(.caption2)
                                .foregroundStyle(Color.eqMuted)
                                .lineLimit(1)
                        }
                    }
                }
                .padding(EQSpacing.sm)
            }
            .background(Color.eqWarmWhite)
            .clipShape(RoundedRectangle(cornerRadius: EQRadius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: EQRadius.md, style: .continuous)
                    .strokeBorder(Color.eqLightTan, lineWidth: 1)
            )
            .eqShadow(radius: 4, y: 2, opacity: 0.06)
        }
        .buttonStyle(.eqScale)
    }

    private var listingPlaceholder: some View {
        ZStack {
            Color.eqMutedBrown
            Image(systemName: listing.type == "horse" ? "figure.equestrian.sports" : "tag.fill")
                .font(.largeTitle)
                .foregroundStyle(Color.eqSaddleBrown.opacity(0.5))
        }
    }
}
