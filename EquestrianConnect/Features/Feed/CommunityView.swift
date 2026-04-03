import SwiftUI

enum CommunityTab: String, CaseIterable {
    case feed = "Feed"
    case marketplace = "Marketplace"
}

struct CommunityView: View {
    @Environment(AuthManager.self) private var auth
    @State private var selectedTab: CommunityTab = .feed
    @State private var feedVM = FeedViewModel()
    @State private var marketVM = MarketplaceViewModel()
    @State private var showCreatePost = false
    @State private var showAddListing = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Segmented picker
                Picker("", selection: $selectedTab) {
                    ForEach(CommunityTab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, EQSpacing.md)
                .padding(.vertical, EQSpacing.sm)

                EQDivider()

                // Content
                switch selectedTab {
                case .feed:
                    feedContent
                case .marketplace:
                    marketplaceContent
                }
            }
            .background(Color.eqWarmWhite.ignoresSafeArea())
            .navigationTitle("Community")
            .eqNavAppearance()
            .eqMoreMenu()
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        if selectedTab == .feed {
                            showCreatePost = true
                        } else {
                            showAddListing = true
                        }
                    } label: {
                        Image(systemName: "plus")
                            .foregroundStyle(.white)
                    }
                }
            }
            .sheet(isPresented: $showCreatePost) {
                CreatePostView(vm: feedVM)
            }
            .sheet(isPresented: $showAddListing) {
                ListingFormView(vm: marketVM)
            }
            .task {
                guard let user = auth.user else { return }
                await feedVM.load(userId: user.id)
                await marketVM.load()
            }
            .refreshable {
                guard let user = auth.user else { return }
                await feedVM.load(userId: user.id)
                await marketVM.load()
            }
        }
    }

    // MARK: - Feed

    @ViewBuilder
    private var feedContent: some View {
        if feedVM.isLoading {
            EQLoadingView()
        } else if feedVM.posts.isEmpty {
            EmptyStateView(
                icon: "rectangle.stack.person.crop.fill",
                title: "No Posts Yet",
                subtitle: "Share a moment with your horses",
                actionTitle: "Create Post",
                action: { showCreatePost = true }
            )
        } else {
            ScrollView {
                LazyVStack(spacing: EQSpacing.md) {
                    ForEach(feedVM.posts) { post in
                        PostCard(
                            post: post,
                            isLiked: feedVM.myLikes.contains(post.id),
                            isOwned: post.author_id == auth.user?.id
                        ) {
                            Task { await feedVM.toggleLike(post: post, userId: auth.user?.id ?? "") }
                        } onDelete: {
                            Task { try? await feedVM.deletePost(post) }
                        }
                    }
                }
                .padding(.horizontal, EQSpacing.md)
                .padding(.vertical, EQSpacing.md)
            }
        }
    }

    // MARK: - Marketplace

    @State private var selectedListing: MarketplaceListing?

    private let typeFilters: [(String, String)] = [
        ("", "All"), ("horse", "Horses"), ("tack", "Tack"),
        ("equipment", "Equipment"), ("trailer", "Trailers")
    ]

    @ViewBuilder
    private var marketplaceContent: some View {
        VStack(spacing: 0) {
            // Filter pills
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: EQSpacing.sm) {
                    ForEach(typeFilters, id: \.0) { value, label in
                        FilterPill(
                            label: label,
                            isSelected: marketVM.selectedType == value
                        ) { marketVM.selectedType = value }
                    }
                }
                .padding(.horizontal, EQSpacing.md)
                .padding(.vertical, EQSpacing.sm)
            }

            if marketVM.isLoading {
                EQLoadingView()
            } else if marketVM.filtered.isEmpty {
                EmptyStateView(
                    icon: "tag.fill",
                    title: "No Listings",
                    subtitle: "Be the first to post a listing.",
                    actionTitle: "Post Listing",
                    action: { showAddListing = true }
                )
            } else {
                ScrollView {
                    LazyVGrid(
                        columns: [GridItem(.flexible()), GridItem(.flexible())],
                        spacing: EQSpacing.sm
                    ) {
                        ForEach(marketVM.filtered) { listing in
                            ListingCard(listing: listing) {
                                selectedListing = listing
                            }
                        }
                    }
                    .padding(EQSpacing.md)
                }
            }
        }
        .sheet(item: $selectedListing) { listing in
            ListingDetailView(listing: listing, vm: marketVM)
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
