import Foundation

struct HorseRegistryEntry: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let nchaNumber: String
    let sex: String          // Stallion | Mare | Gelding
    let foalDate: String?    // "4/1/1990"
    let lifetimeEarnings: Double?
    let owners: String?
    let homeCircuit: String?

    var year: String? {
        guard let f = foalDate, let last = f.split(separator: "/").last else { return nil }
        return String(last)
    }

    var subtitle: String {
        var parts: [String] = []
        if let y = year { parts.append(y) }
        parts.append(sex)
        if let e = lifetimeEarnings, e > 0 {
            parts.append("$\(Int(e).formatted())")
        }
        return parts.joined(separator: " · ")
    }

    var genderValue: String {
        switch sex.lowercased() {
        case "stallion": return "stallion"
        case "mare":     return "mare"
        case "gelding":  return "gelding"
        default:         return ""
        }
    }

    /// Converts "4/1/1990" to "1990-04-01" (Horse.date_of_birth format).
    var dateOfBirthISO: String? {
        guard let f = foalDate else { return nil }
        let parts = f.split(separator: "/").map(String.init)
        guard parts.count == 3,
              let m = Int(parts[0]),
              let d = Int(parts[1]),
              let y = Int(parts[2]) else { return nil }
        return String(format: "%04d-%02d-%02d", y, m, d)
    }
}

@Observable
final class HorseRegistry {
    static let shared = HorseRegistry()

    private(set) var entries: [HorseRegistryEntry] = []
    private var loaded = false
    private let queue = DispatchQueue(label: "horse-registry", qos: .userInitiated)

    private init() {}

    /// Load CSV off the main thread. Safe to call multiple times.
    func loadIfNeeded() {
        guard !loaded else { return }
        loaded = true
        queue.async { [weak self] in
            let parsed = Self.parseBundledCSV()
            DispatchQueue.main.async { self?.entries = parsed }
        }
    }

    /// Case-insensitive prefix/contains match on name. Prefix hits ranked first.
    func search(_ query: String, limit: Int = 8) -> [HorseRegistryEntry] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard q.count >= 2 else { return [] }
        var prefix: [HorseRegistryEntry] = []
        var contains: [HorseRegistryEntry] = []
        for e in entries {
            let n = e.name.lowercased()
            if n.hasPrefix(q) {
                prefix.append(e)
                if prefix.count >= limit { break }
            } else if n.contains(q) {
                contains.append(e)
            }
        }
        return Array((prefix + contains).prefix(limit))
    }

    private static func parseBundledCSV() -> [HorseRegistryEntry] {
        guard let url = Bundle.main.url(forResource: "ncha_horses", withExtension: "csv"),
              let text = try? String(contentsOf: url, encoding: .utf8) else {
            return []
        }
        var out: [HorseRegistryEntry] = []
        out.reserveCapacity(5000)
        let lines = text.split(separator: "\n", omittingEmptySubsequences: true)
        for (i, line) in lines.enumerated() where i > 0 {
            let cols = line.split(separator: ",", omittingEmptySubsequences: false).map(String.init)
            guard cols.count >= 7 else { continue }
            out.append(
                HorseRegistryEntry(
                    name: cols[0],
                    nchaNumber: cols[1],
                    sex: cols[2],
                    foalDate: cols[3].isEmpty ? nil : cols[3],
                    lifetimeEarnings: Double(cols[4]),
                    owners: cols[5].isEmpty ? nil : cols[5],
                    homeCircuit: cols[6].isEmpty ? nil : cols[6]
                )
            )
        }
        return out
    }
}
