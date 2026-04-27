import Foundation
import Observation

@Observable
final class HorsesViewModel {
    var horses: [Horse] = []
    var isLoading = false
    var error: String?
    var searchText = ""

    var filtered: [Horse] {
        guard !searchText.isEmpty else { return horses }
        let q = searchText.lowercased()
        return horses.filter {
            $0.name.lowercased().contains(q) ||
            ($0.barn_name?.lowercased().contains(q) ?? false) ||
            ($0.breed?.lowercased().contains(q) ?? false)
        }
    }

    private let client = SupabaseClient.shared

    func load(userId: String, isTrainer: Bool = false) async {
        #if targetEnvironment(simulator)
        await MainActor.run { loadSimulatorMock(isTrainer: isTrainer) }
        return
        #endif
        if isDemoMode {
            await MainActor.run { loadSimulatorMock(isTrainer: isTrainer) }
            return
        }
        await MainActor.run { isLoading = true; error = nil }
        do {
            let field = isTrainer ? "trainer_id" : "owner_id"
            let fetched: [Horse] = try await client.filter(
                table: "horses",
                query: [URLQueryItem(name: field, value: "eq.\(userId)")],
                order: "name.asc",
                limit: 100
            )
            await MainActor.run { horses = fetched; isLoading = false }
        } catch {
            let desc = error.localizedDescription
            await MainActor.run { self.error = desc; isLoading = false }
        }
    }

    @MainActor
    private func loadSimulatorMock(isTrainer: Bool) {
        let imgMidnight = "https://images.unsplash.com/photo-1670212433014-b2435aca06a4?w=400&fit=crop"
        let imgArrow = "https://images.unsplash.com/photo-1517326451550-8612522c096e?w=400&fit=crop"
        let imgStorm = "https://images.unsplash.com/photo-1641226469021-f81abb75108c?w=400&fit=crop"
        let imgRuby = "https://images.unsplash.com/photo-1553284965-83fd3e82fa5a?w=400&fit=crop"
        horses = [
            Horse(id: "h1", name: "Midnight Star", barn_name: "Midnight",
                  breed: "Thoroughbred", color: "Black", date_of_birth: "2018-04-15",
                  gender: "mare", registration_number: "TB-2018-4421", discipline: "Dressage",
                  owner_id: "preview-owner", trainer_id: isTrainer ? "preview-trainer" : nil,
                  profile_image: imgMidnight, total_earnings: 12400, created_date: nil),
            Horse(id: "h2", name: "Golden Arrow", barn_name: "Arrow",
                  breed: "Quarter Horse", color: "Palomino", date_of_birth: "2015-07-22",
                  gender: "gelding", registration_number: "QH-2015-8810", discipline: "Western Pleasure",
                  owner_id: isTrainer ? "sarah-id" : "preview-owner",
                  trainer_id: isTrainer ? "preview-trainer" : nil,
                  profile_image: imgArrow, total_earnings: 8200, created_date: nil),
            Horse(id: "h3", name: "Storm Chaser", barn_name: nil,
                  breed: "Warmblood", color: "Dapple Grey", date_of_birth: "2019-01-10",
                  gender: "stallion", registration_number: nil, discipline: "Jumping",
                  owner_id: isTrainer ? "mike-id" : "preview-owner",
                  trainer_id: isTrainer ? "preview-trainer" : nil,
                  profile_image: imgStorm, total_earnings: nil, created_date: nil),
            Horse(id: "h4", name: "Ruby Red", barn_name: "Ruby",
                  breed: "Arabian", color: "Chestnut", date_of_birth: "2017-09-03",
                  gender: "mare", registration_number: "AR-2017-0391", discipline: "Endurance",
                  owner_id: isTrainer ? "lisa-id" : "preview-owner",
                  trainer_id: isTrainer ? "preview-trainer" : nil,
                  profile_image: imgRuby, total_earnings: 3100, created_date: nil),
        ]
        isLoading = false
    }

    @MainActor
    func create(_ horse: Horse) async throws {
        let created: Horse = try await client.create(table: "horses", data: horse)
        horses.insert(created, at: 0)
    }

    @MainActor
    func update(_ horse: Horse) async throws {
        let updated: Horse = try await client.update(table: "horses", id: horse.id, data: horse)
        if let idx = horses.firstIndex(where: { $0.id == horse.id }) {
            horses[idx] = updated
        }
    }

    @MainActor
    func delete(_ horse: Horse) async throws {
        try await client.delete(table: "horses", id: horse.id)
        horses.removeAll { $0.id == horse.id }
    }
}
