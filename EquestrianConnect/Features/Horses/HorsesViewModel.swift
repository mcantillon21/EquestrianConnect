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

    private let client = Base44Client.shared

    func load(userEmail: String, isTrainer: Bool = false) async {
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
            let field = isTrainer ? "trainer_email" : "owner_email"
            let fetched: [Horse] = try await client.filter(
                entity: "Horse",
                query: [field: userEmail],
                sort: "name",
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
        let imgMidnight = "https://upload.wikimedia.org/wikipedia/commons/thumb/3/36/Applebite-Gentlemen.jpg/400px-Applebite-Gentlemen.jpg"
        let imgArrow = "https://upload.wikimedia.org/wikipedia/commons/thumb/5/53/Mare_and_foal_%28Kvetina-Marie%29.jpg/400px-Mare_and_foal_%28Kvetina-Marie%29.jpg"
        let imgStorm = "https://upload.wikimedia.org/wikipedia/commons/thumb/7/7b/WCLV07m.JPG/400px-WCLV07m.JPG"
        let imgRuby = "https://upload.wikimedia.org/wikipedia/commons/thumb/5/54/Halterstandingshotarabianone.jpg/400px-Halterstandingshotarabianone.jpg"
        horses = [
            Horse(id: "h1", name: "Midnight Star", barn_name: "Midnight",
                  breed: "Thoroughbred", color: "Black", date_of_birth: "2018-04-15",
                  gender: "mare", registration_number: "TB-2018-4421", discipline: "Dressage",
                  owner_email: "preview@eq.app", trainer_email: isTrainer ? "preview@eq.app" : nil,
                  profile_image: imgMidnight, total_earnings: 12400, created_date: nil),
            Horse(id: "h2", name: "Golden Arrow", barn_name: "Arrow",
                  breed: "Quarter Horse", color: "Palomino", date_of_birth: "2015-07-22",
                  gender: "gelding", registration_number: "QH-2015-8810", discipline: "Western Pleasure",
                  owner_email: isTrainer ? "sarah@eq.app" : "preview@eq.app",
                  trainer_email: isTrainer ? "preview@eq.app" : nil,
                  profile_image: imgArrow, total_earnings: 8200, created_date: nil),
            Horse(id: "h3", name: "Storm Chaser", barn_name: nil,
                  breed: "Warmblood", color: "Dapple Grey", date_of_birth: "2019-01-10",
                  gender: "stallion", registration_number: nil, discipline: "Jumping",
                  owner_email: isTrainer ? "mike@eq.app" : "preview@eq.app",
                  trainer_email: isTrainer ? "preview@eq.app" : nil,
                  profile_image: imgStorm, total_earnings: nil, created_date: nil),
            Horse(id: "h4", name: "Ruby Red", barn_name: "Ruby",
                  breed: "Arabian", color: "Chestnut", date_of_birth: "2017-09-03",
                  gender: "mare", registration_number: "AR-2017-0391", discipline: "Endurance",
                  owner_email: isTrainer ? "lisa@eq.app" : "preview@eq.app",
                  trainer_email: isTrainer ? "preview@eq.app" : nil,
                  profile_image: imgRuby, total_earnings: 3100, created_date: nil),
        ]
        isLoading = false
    }

    @MainActor
    func create(_ horse: Horse) async throws {
        let created: Horse = try await client.create(entity: "Horse", data: horse)
        horses.insert(created, at: 0)
    }

    @MainActor
    func update(_ horse: Horse) async throws {
        let updated: Horse = try await client.update(entity: "Horse", id: horse.id, data: horse)
        if let idx = horses.firstIndex(where: { $0.id == horse.id }) {
            horses[idx] = updated
        }
    }

    @MainActor
    func delete(_ horse: Horse) async throws {
        try await client.delete(entity: "Horse", id: horse.id)
        horses.removeAll { $0.id == horse.id }
    }
}
