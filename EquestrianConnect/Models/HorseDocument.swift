import SwiftUI

struct HorseDocument: Codable, Identifiable, Hashable {
    var id: String
    var horse_id: String
    var title: String
    var type: String     // see allTypes below
    var date: String?    // ISO 8601 date string
    var notes: String?
    var file_url: String?
    var file_name: String?   // filename when a non-image file is attached
    var imageData: Data?     // JPEG/PNG photo of a physical document
    var uploaded_by: String?
    var created_date: String?

    // MARK: - Display helpers

    var typeLabel: String {
        switch type {
        case "vet_record":          return "Vet Record"
        case "birth_certificate":   return "Birth Certificate"
        case "registration":        return "Registration"
        case "coggins":             return "Coggins Test"
        case "health_certificate":  return "Health Certificate"
        case "vaccine":             return "Vaccination"
        case "farrier_record":      return "Farrier Record"
        case "insurance":           return "Insurance"
        default:                    return "Document"
        }
    }

    var typeIcon: String {
        switch type {
        case "vet_record":          return "stethoscope"
        case "birth_certificate":   return "doc.text.fill"
        case "registration":        return "rosette"
        case "coggins":             return "cross.vial.fill"
        case "health_certificate":  return "checkmark.seal.fill"
        case "vaccine":             return "syringe.fill"
        case "farrier_record":      return "hammer.fill"
        case "insurance":           return "shield.fill"
        default:                    return "doc.fill"
        }
    }

    var typeColor: Color {
        switch type {
        case "vet_record", "coggins", "health_certificate": return .blue
        case "vaccine":             return Color(red: 0.18, green: 0.60, blue: 0.35)   // forest green
        case "birth_certificate":   return Color(red: 0.55, green: 0.35, blue: 0.18)   // eqSaddleBrown-ish
        case "registration":        return Color(red: 0.65, green: 0.45, blue: 0.10)   // amber
        case "farrier_record":      return Color(red: 0.70, green: 0.38, blue: 0.12)   // orange-brown
        case "insurance":           return Color(red: 0.42, green: 0.28, blue: 0.65)   // purple
        default:                    return Color(red: 0.45, green: 0.45, blue: 0.45)   // grey
        }
    }

    // MARK: - Metadata

    static let allTypes: [(value: String, label: String)] = [
        ("vet_record",          "Vet Record"),
        ("birth_certificate",   "Birth Certificate"),
        ("registration",        "Show Registration"),
        ("coggins",             "Coggins Test"),
        ("health_certificate",  "Health Certificate"),
        ("vaccine",             "Vaccination Record"),
        ("farrier_record",      "Farrier Record"),
        ("insurance",           "Insurance Document"),
        ("other",               "Other"),
    ]

    static func == (lhs: HorseDocument, rhs: HorseDocument) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

// MARK: - Demo / Mock Data

extension HorseDocument {
    static func mockDocuments(for horseId: String) -> [HorseDocument] {
        switch horseId {

        // ─── Midnight Star — Thoroughbred Mare ───────────────────────────────
        case "h1":
            return [
                HorseDocument(
                    id: "d1-1", horse_id: "h1",
                    title: "USEF Registration Certificate",
                    type: "registration", date: "2018-09-10",
                    notes: "Registration #: EQ-2018-TBR-4471. Registered with USEF under 'Midnight Star'. Eligible for Dressage competitions through 2026 season.",
                    file_url: nil, uploaded_by: "preview@eq.app", created_date: "2024-01-15"),
                HorseDocument(
                    id: "d1-2", horse_id: "h1",
                    title: "Annual Wellness Exam — Mar 2025",
                    type: "vet_record", date: "2025-03-14",
                    notes: "Dr. Sarah Miller, DVM. All vitals normal. Weight: 1,100 lbs. Heart/lungs clear. Dental float completed. Hind suspensory palpation — no concerns. Next exam due March 2026.",
                    file_url: nil, uploaded_by: "preview@eq.app", created_date: "2025-03-14"),
                HorseDocument(
                    id: "d1-3", horse_id: "h1",
                    title: "Coggins Test — Jan 2026",
                    type: "coggins", date: "2026-01-08",
                    notes: "Equine Infectious Anemia test result: NEGATIVE. Issued by Riverside Equine Clinic. Certificate #: CAL-2026-00142. Valid through January 2027.",
                    file_url: nil, uploaded_by: "preview@eq.app", created_date: "2026-01-08"),
                HorseDocument(
                    id: "d1-4", horse_id: "h1",
                    title: "Interstate Health Certificate — Feb 2026",
                    type: "health_certificate", date: "2026-02-20",
                    notes: "Issued for transport to Spring Classic Horse Show. Valid 30 days from issue. Dr. Sarah Miller, DVM. Origin: Rolling Hills Barn, CA. Destination: County Equestrian Center.",
                    file_url: nil, uploaded_by: "preview@eq.app", created_date: "2026-02-20"),
                HorseDocument(
                    id: "d1-5", horse_id: "h1",
                    title: "Spring Vaccination Record — Apr 2025",
                    type: "vaccine", date: "2025-04-02",
                    notes: "Administered: West Nile Virus, EEE/WEE, Tetanus, Influenza/Rhinopneumonitis, Rabies. All boosters current. Next due: April 2026. Dr. Sarah Miller, DVM.",
                    file_url: nil, uploaded_by: "preview@eq.app", created_date: "2025-04-02"),
            ]

        // ─── Golden Arrow — Quarter Horse Gelding ────────────────────────────
        case "h2":
            return [
                HorseDocument(
                    id: "d2-1", horse_id: "h2",
                    title: "AQHA Registration Papers",
                    type: "registration", date: "2015-11-03",
                    notes: "Registration #: 5924817. Sire: Golden Sunrise (AQHA 5102344). Dam: Arrow's Pride (AQHA 4988201). Registered color: Palomino. Microchip on file.",
                    file_url: nil, uploaded_by: "preview@eq.app", created_date: "2024-02-10"),
                HorseDocument(
                    id: "d2-2", horse_id: "h2",
                    title: "Birth Certificate",
                    type: "birth_certificate", date: "2015-07-22",
                    notes: "Foal certificate issued by Sunridge Quarter Horse Farm. Breeder: Thomas & Janet Hendricks, Tulsa OK. Color: Palomino. Brand: Registered left hip. DNA sample on file with AQHA.",
                    file_url: nil, uploaded_by: "preview@eq.app", created_date: "2024-02-10"),
                HorseDocument(
                    id: "d2-3", horse_id: "h2",
                    title: "Coggins Test — Jan 2026",
                    type: "coggins", date: "2026-01-15",
                    notes: "EIA test result: NEGATIVE. Issued by Valley Equine Hospital. Certificate #: TX-2026-55821. Valid through January 2027. Required for all show entries.",
                    file_url: nil, uploaded_by: "preview@eq.app", created_date: "2026-01-15"),
                HorseDocument(
                    id: "d2-4", horse_id: "h2",
                    title: "Farrier Visit — Feb 2026",
                    type: "farrier_record", date: "2026-02-10",
                    notes: "Full reset. Trimmed and re-shod all four feet. Front: regular keg shoes size 1. Hind: plain plates. No thrush or white line noted. Next visit in 6 weeks. Farrier: Jake Donovan.",
                    file_url: nil, uploaded_by: "preview@eq.app", created_date: "2026-02-10"),
                HorseDocument(
                    id: "d2-5", horse_id: "h2",
                    title: "Annual Vaccination — May 2025",
                    type: "vaccine", date: "2025-05-15",
                    notes: "Administered: West Nile, EEE/WEE/Tetanus combo (Fluvac Innovator), Influenza/Rhino. All boosters current through May 2026. Dr. Karen Walsh, DVM.",
                    file_url: nil, uploaded_by: "preview@eq.app", created_date: "2025-05-15"),
            ]

        // ─── Storm Chaser — Warmblood Stallion ───────────────────────────────
        case "h3":
            return [
                HorseDocument(
                    id: "d3-1", horse_id: "h3",
                    title: "KWPN Registration Certificate",
                    type: "registration", date: "2019-06-14",
                    notes: "Koninklijk Warmbloed Paardenstamboek Nederland. Studbook #: NL-2019-00847. Sire: De Niro (KWPN). Dam: Scarlett's Dream. Licensed for sport. DNA-typed and on file.",
                    file_url: nil, uploaded_by: "preview@eq.app", created_date: "2024-03-01"),
                HorseDocument(
                    id: "d3-2", horse_id: "h3",
                    title: "Birth Certificate — KWPN Foal",
                    type: "birth_certificate", date: "2019-01-10",
                    notes: "Issued by Oakwood Warmblood Stud, Netherlands. Microchip: 981000012345678. Foal inspection score: 77 pts. Breed type confirmed by KWPN inspector J. van der Berg.",
                    file_url: nil, uploaded_by: "preview@eq.app", created_date: "2024-03-01"),
                HorseDocument(
                    id: "d3-3", horse_id: "h3",
                    title: "5-Stage Pre-Purchase Exam — Aug 2023",
                    type: "vet_record", date: "2023-08-22",
                    notes: "Dr. Michael Torres, DVM. Radiographs: 16 views — no significant findings. Flexion tests: All four limbs passed. Scope: Clean airways. Trot-up: Sound both directions. Overall assessment: PASSED.",
                    file_url: nil, uploaded_by: "preview@eq.app", created_date: "2024-03-01"),
                HorseDocument(
                    id: "d3-4", horse_id: "h3",
                    title: "Coggins Test — Dec 2025",
                    type: "coggins", date: "2025-12-04",
                    notes: "EIA result: NEGATIVE. Riverside Equine Diagnostic Lab. Certificate #: CAL-2025-88234. Valid through December 2026. Required for interstate transport.",
                    file_url: nil, uploaded_by: "preview@eq.app", created_date: "2025-12-04"),
                HorseDocument(
                    id: "d3-5", horse_id: "h3",
                    title: "Mortality & Major Medical Insurance",
                    type: "insurance", date: "2025-01-01",
                    notes: "Policy #: EQI-2025-MC-00342. Insurer: Markel Insurance. Coverage: $45,000 mortality, $15,000 major medical. Annual premium: $2,475. Renewal due: January 2026. Claims: 1-800-555-8742.",
                    file_url: nil, uploaded_by: "preview@eq.app", created_date: "2025-01-01"),
            ]

        // ─── Ruby Red — Arabian Mare ──────────────────────────────────────────
        case "h4":
            return [
                HorseDocument(
                    id: "d4-1", horse_id: "h4",
                    title: "AHA Registration Certificate",
                    type: "registration", date: "2017-12-01",
                    notes: "Arabian Horse Association registration #: 0661782. Pure Arabian. Sire: Marwan Al Shaqab (AHA 522001). Dam: Ruby's Desert Rose. Eligible for endurance and breed competitions.",
                    file_url: nil, uploaded_by: "preview@eq.app", created_date: "2024-04-01"),
                HorseDocument(
                    id: "d4-2", horse_id: "h4",
                    title: "AERC Pre-Ride Vet Exam — Nov 2025",
                    type: "vet_record", date: "2025-11-10",
                    notes: "American Endurance Ride Conference exam. CRI (cardiac recovery index): 44/44. Gut sounds: 4/4 all quadrants. Mucous membranes: pink & moist. Hydration: Good. CLEARED TO COMPETE.",
                    file_url: nil, uploaded_by: "preview@eq.app", created_date: "2025-11-10"),
                HorseDocument(
                    id: "d4-3", horse_id: "h4",
                    title: "Interstate Health Certificate — Jan 2026",
                    type: "health_certificate", date: "2026-01-28",
                    notes: "Issued for transport to Tevis Cup 100 qualifier, Auburn CA. Dr. Linda Prescott, DVM. Horse free of visible signs of infectious disease. Temperature: 99.8°F. Valid 30 days.",
                    file_url: nil, uploaded_by: "preview@eq.app", created_date: "2026-01-28"),
                HorseDocument(
                    id: "d4-4", horse_id: "h4",
                    title: "Spring Vaccination Record — Mar 2025",
                    type: "vaccine", date: "2025-03-20",
                    notes: "Spring boosters: West Nile, EEE/WEE/Tetanus, Influenza, Rhinopneumonitis, Potomac Horse Fever. Fall Flu/Rhino booster due September 2025. Dr. Linda Prescott, DVM.",
                    file_url: nil, uploaded_by: "preview@eq.app", created_date: "2025-03-20"),
                HorseDocument(
                    id: "d4-5", horse_id: "h4",
                    title: "Coggins Test — Jan 2026",
                    type: "coggins", date: "2026-01-20",
                    notes: "EIA result: NEGATIVE. Desert Equine Health Center. Certificate #: AZ-2026-00771. Required for all AERC competitions. Valid through January 2027.",
                    file_url: nil, uploaded_by: "preview@eq.app", created_date: "2026-01-20"),
            ]

        default:
            return []
        }
    }
}
