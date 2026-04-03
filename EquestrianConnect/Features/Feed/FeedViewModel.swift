import Foundation
import Observation

@Observable
final class FeedViewModel {
    var posts: [Post] = []
    var myLikes: Set<String> = []  // post IDs I've liked
    var isLoading = false
    var error: String?

    private let client = SupabaseClient.shared

    func load(userId: String) async {
        await MainActor.run { isLoading = true; error = nil }
        async let postsTask: [Post] = try client.list(table: "posts", order: "created_date.desc", limit: 50)
        async let likesTask: [Like] = try client.filter(
            table: "likes",
            query: [URLQueryItem(name: "user_id", value: "eq.\(userId)")],
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
    func toggleLike(post: Post, userId: String) async {
        guard let idx = posts.firstIndex(where: { $0.id == post.id }) else { return }
        if myLikes.contains(post.id) {
            // Unlike
            myLikes.remove(post.id)
            posts[idx].like_count = max(0, (posts[idx].like_count ?? 0) - 1)
            Task {
                if let likes: [Like] = try? await client.filter(
                    table: "likes",
                    query: [URLQueryItem(name: "post_id", value: "eq.\(post.id)"),
                            URLQueryItem(name: "user_id", value: "eq.\(userId)")]
                ) {
                    if let mine = likes.first {
                        try? await client.delete(table: "likes", id: mine.id)
                    }
                }
            }
        } else {
            // Like
            myLikes.insert(post.id)
            posts[idx].like_count = (posts[idx].like_count ?? 0) + 1
            Task {
                let like = Like(id: UUID().uuidString, post_id: post.id, user_id: userId)
                let _: Like? = try? await client.create(table: "likes", data: like)
            }
        }
    }

    @MainActor
    func createPost(_ post: Post) async throws {
        let created: Post = try await client.create(table: "posts", data: post)
        posts.insert(created, at: 0)
    }

    @MainActor
    func deletePost(_ post: Post) async throws {
        try await client.delete(table: "posts", id: post.id)
        posts.removeAll { $0.id == post.id }
    }
}
