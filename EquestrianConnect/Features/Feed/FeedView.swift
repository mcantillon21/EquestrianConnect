import SwiftUI
import PhotosUI

struct FeedView: View {
    @Environment(AuthManager.self) private var auth
    @State private var vm = FeedViewModel()
    @State private var showCreatePost = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.eqWarmWhite.ignoresSafeArea()

                if vm.isLoading {
                    EQLoadingView()
                } else if vm.posts.isEmpty {
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
                            ForEach(vm.posts) { post in
                                PostCard(
                                    post: post,
                                    isLiked: vm.myLikes.contains(post.id),
                                    isOwned: post.author_email == auth.user?.email
                                ) {
                                    Task { await vm.toggleLike(post: post, userEmail: auth.user?.email ?? "") }
                                } onDelete: {
                                    Task { try? await vm.deletePost(post) }
                                }
                            }
                        }
                        .padding(.horizontal, EQSpacing.md)
                        .padding(.vertical, EQSpacing.md)
                    }
                }
            }
            .navigationTitle("Community")
            .eqNavAppearance()
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showCreatePost = true
                    } label: {
                        Image(systemName: "plus")
                            .foregroundStyle(.white)
                    }
                }
            }
            .sheet(isPresented: $showCreatePost) {
                CreatePostView(vm: vm)
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

// MARK: - Post Card

struct PostCard: View {
    let post: Post
    let isLiked: Bool
    let isOwned: Bool
    let onLike: () -> Void
    let onDelete: () -> Void

    @State private var showDeleteAlert = false

    var body: some View {
        EQCard(padding: 0) {
            VStack(alignment: .leading, spacing: 0) {
                // Header
                HStack(spacing: EQSpacing.sm) {
                    InitialsAvatar(text: post.author_name ?? post.author_email ?? "?", size: 38)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(post.author_name ?? post.author_email ?? "User")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.eqDarkBrown)
                        if let date = post.created_date {
                            Text(date.toRelativeDate())
                                .font(.caption)
                                .foregroundStyle(Color.eqMuted)
                        }
                    }
                    Spacer()
                    if isOwned {
                        Menu {
                            Button(role: .destructive) {
                                showDeleteAlert = true
                            } label: {
                                Label("Delete Post", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                                .font(.body)
                                .foregroundStyle(Color.eqMuted)
                        }
                    }
                }
                .padding(EQSpacing.md)

                // Media
                if let url = post.media_url, !url.isEmpty {
                    AsyncImage(url: URL(string: url)) { phase in
                        switch phase {
                        case .success(let img):
                            img.resizable().scaledToFit()
                        default:
                            Color.eqMutedBrown.frame(height: 200)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }

                // Caption
                if let caption = post.caption, !caption.isEmpty {
                    Text(caption)
                        .font(.body)
                        .foregroundStyle(Color.eqDarkBrown)
                        .padding(.horizontal, EQSpacing.md)
                        .padding(.top, EQSpacing.sm)
                }

                // Horse tag
                if let horseName = post.horse_name {
                    HStack {
                        Image(systemName: "figure.equestrian.sports")
                            .font(.caption)
                        Text(horseName)
                            .font(.caption.weight(.medium))
                    }
                    .foregroundStyle(Color.eqChocolate)
                    .padding(.horizontal, EQSpacing.md)
                    .padding(.top, EQSpacing.xs)
                }

                // For sale badge
                if post.for_sale == true, let price = post.price {
                    EQBadge(text: "For Sale · \(price.currencyString)")
                        .padding(.horizontal, EQSpacing.md)
                        .padding(.top, EQSpacing.xs)
                }

                // Actions
                HStack(spacing: EQSpacing.lg) {
                    Button(action: onLike) {
                        HStack(spacing: 4) {
                            Image(systemName: isLiked ? "heart.fill" : "heart")
                                .font(.body)
                                .foregroundStyle(isLiked ? Color.red : Color.eqMuted)
                            Text("\(post.like_count ?? 0)")
                                .font(.subheadline)
                                .foregroundStyle(Color.eqMuted)
                        }
                    }

                    HStack(spacing: 4) {
                        Image(systemName: "bubble.right")
                            .font(.body)
                            .foregroundStyle(Color.eqMuted)
                        Text("\(post.comment_count ?? 0)")
                            .font(.subheadline)
                            .foregroundStyle(Color.eqMuted)
                    }

                    Spacer()

                    if let loc = post.location, !loc.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "mappin")
                                .font(.caption)
                                .foregroundStyle(Color.eqMuted)
                            Text(loc)
                                .font(.caption)
                                .foregroundStyle(Color.eqMuted)
                        }
                    }
                }
                .padding(EQSpacing.md)
            }
        }
        .alert("Delete post?", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive, action: onDelete)
        }
    }
}

// MARK: - Create Post

struct CreatePostView: View {
    let vm: FeedViewModel
    @Environment(AuthManager.self) private var auth
    @Environment(\.dismiss) private var dismiss

    @State private var caption = ""
    @State private var location = ""
    @State private var horseId = ""
    @State private var horseName = ""
    @State private var forSale = false
    @State private var price = ""
    @State private var photoItem: PhotosPickerItem? = nil
    @State private var selectedImageData: Data? = nil
    @State private var uploadedURL: String? = nil
    @State private var isUploading = false
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

                        // Photo picker
                        PhotosPicker(selection: $photoItem, matching: .images) {
                            if let data = selectedImageData, let uiImg = UIImage(data: data) {
                                Image(uiImage: uiImg)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(maxWidth: .infinity)
                                    .frame(maxHeight: 200)
                                    .clipShape(RoundedRectangle(cornerRadius: EQRadius.md))
                            } else {
                                HStack {
                                    Image(systemName: "photo.badge.plus")
                                    Text("Add Photo")
                                }
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(Color.eqSaddleBrown)
                                .frame(maxWidth: .infinity)
                                .frame(height: 80)
                                .background(Color.eqMutedBrown, in: RoundedRectangle(cornerRadius: EQRadius.md))
                            }
                        }
                        .onChange(of: photoItem) { _, newItem in
                            Task { await handlePhoto(newItem) }
                        }

                        VStack(spacing: EQSpacing.md) {
                            EQTextEditor(label: "Caption", placeholder: "What's happening at the barn?", text: $caption)
                            EQTextField(label: "Location", placeholder: "Optional", text: $location, icon: "mappin")
                            EQTextField(label: "Horse Name", placeholder: "Tag a horse", text: $horseName, icon: "figure.equestrian.sports")

                            VStack(alignment: .leading, spacing: EQSpacing.sm) {
                                Toggle("This horse is for sale", isOn: $forSale)
                                    .font(.subheadline.weight(.medium))
                                    .tint(Color.eqSaddleBrown)
                                if forSale {
                                    EQTextField(label: "Price ($)", placeholder: "0", text: $price, keyboard: .numberPad)
                                }
                            }
                            .padding(EQSpacing.md)
                            .background(Color.eqCream, in: RoundedRectangle(cornerRadius: EQRadius.md))
                        }
                        .padding(.horizontal, EQSpacing.md)

                        EQPrimaryButton(title: isSaving ? "Posting…" : "Post", isLoading: isSaving) {
                            Task { await post() }
                        }
                        .padding(.horizontal, EQSpacing.md)
                        .padding(.bottom, EQSpacing.xl)
                    }
                    .padding(.top, EQSpacing.md)
                }
            }
            .navigationTitle("New Post")
            .navigationBarTitleDisplayMode(.inline)
            .eqNavAppearance()
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }.foregroundStyle(.white)
                }
            }
        }
    }

    private func handlePhoto(_ item: PhotosPickerItem?) async {
        guard let item, let data = try? await item.loadTransferable(type: Data.self) else { return }
        selectedImageData = data
        isUploading = true
        uploadedURL = try? await Base44Client.shared.uploadFile(imageData: data)
        isUploading = false
    }

    private func post() async {
        isSaving = true
        error = nil
        let p = Post(
            id: UUID().uuidString,
            author_email: auth.user?.email,
            author_name: auth.user?.full_name,
            caption: caption.isEmpty ? nil : caption,
            media_type: uploadedURL != nil ? "photo" : nil,
            media_url: uploadedURL,
            horse_name: horseName.isEmpty ? nil : horseName,
            for_sale: forSale,
            price: Double(price),
            location: location.isEmpty ? nil : location,
            created_date: Date().iso8601String
        )
        do {
            try await vm.createPost(p)
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
        isSaving = false
    }
}
