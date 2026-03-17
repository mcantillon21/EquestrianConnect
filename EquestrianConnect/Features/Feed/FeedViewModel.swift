import Foundation
import Observation

@Observable
final class FeedViewModel {
    var posts: [Post] = []
    var myLikes: Set<String> = []  // post IDs I've liked
    var isLoading = false
    var error: String?

    private let client = Base44Client.shared

    func load(userEmail: String) async {
        await MainActor.run { isLoading = true; error = nil }
        async let postsTask: [Post] = try client.list(entity: "Post", sort: "-created_date", limit: 50)
        async let likesTask: [Like] = try client.filter(
            entity: "Like",
            query: ["user_email": userEmail],
            limit: 200
        )
        do {
            let (p, l) = try await (postsTask, likesTask)
            let likeIds = Set(l.map { $0.post_id })
            await MainActor.run {
                posts = p
                myLikes = likeIds
                isLoading = false
            }
        } catch {
            let desc = error.localizedDescription
            await MainActor.run { self.error = desc; isLoading = false }
        }
    }

    @MainActor
    func toggleLike(post: Post, userEmail: String) async {
        guard let idx = posts.firstIndex(where: { $0.id == post.id }) else { return }
        if myLikes.contains(post.id) {
            // Unlike
            myLikes.remove(post.id)
            posts[idx].like_count = max(0, (posts[idx].like_count ?? 0) - 1)
            // Delete like from API (best effort)
            Task {
                if let likes: [Like] = try? await client.filter(
                    entity: "Like",
                    query: ["post_id": post.id]
                ) {
                    if let mine = likes.first(where: { $0.user_email == userEmail }) {
                        try? await client.delete(entity: "Like", id: mine.id)
                    }
                }
            }
        } else {
            // Like
            myLikes.insert(post.id)
            posts[idx].like_count = (posts[idx].like_count ?? 0) + 1
            Task {
                let like = Like(id: UUID().uuidString, post_id: post.id, user_email: userEmail)
                let _: Like? = try? await client.create(entity: "Like", data: like)
            }
        }
    }

    @MainActor
    func createPost(_ post: Post) async throws {
        let created: Post = try await client.create(entity: "Post", data: post)
        posts.insert(created, at: 0)
    }

    @MainActor
    func deletePost(_ post: Post) async throws {
        try await client.delete(entity: "Post", id: post.id)
        posts.removeAll { $0.id == post.id }
    }
}
