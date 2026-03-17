import Foundation
import Observation

@Observable
final class MarketplaceViewModel {
    var listings: [MarketplaceListing] = []
    var isLoading = false
    var error: String?
    var searchText = ""
    var selectedType = ""

    var filtered: [MarketplaceListing] {
        var result = listings
        if !searchText.isEmpty {
            let q = searchText.lowercased()
            result = result.filter {
                $0.title.lowercased().contains(q) ||
                ($0.breed?.lowercased().contains(q) ?? false) ||
                ($0.description?.lowercased().contains(q) ?? false) ||
                ($0.location?.lowercased().contains(q) ?? false)
            }
        }
        if !selectedType.isEmpty {
            result = result.filter { $0.type == selectedType }
        }
        return result
    }

    private let client = Base44Client.shared

    func load() async {
        await MainActor.run { isLoading = true; error = nil }
        do {
            let fetched: [MarketplaceListing] = try await client.list(
                entity: "MarketplaceListing",
                sort: "-created_date",
                limit: 100
            )
            await MainActor.run { listings = fetched; isLoading = false }
        } catch {
            let desc = error.localizedDescription
            await MainActor.run { self.error = desc; isLoading = false }
        }
    }

    @MainActor
    func create(_ listing: MarketplaceListing) async throws {
        let created: MarketplaceListing = try await client.create(entity: "MarketplaceListing", data: listing)
        listings.insert(created, at: 0)
    }

    @MainActor
    func delete(_ listing: MarketplaceListing) async throws {
        try await client.delete(entity: "MarketplaceListing", id: listing.id)
        listings.removeAll { $0.id == listing.id }
    }
}
