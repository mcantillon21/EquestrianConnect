import SwiftUI

// MARK: - Color Palette

extension Color {
    // Neutrals — warm linen-to-ink scale
    static let eqInk          = Color(red: 0.102, green: 0.082, blue: 0.063)  // #1A1510 near-black
    static let eqBark         = Color(red: 0.365, green: 0.247, blue: 0.176)  // #5D3F2D dark bark
    static let eqLeather      = Color(red: 0.529, green: 0.380, blue: 0.282)  // #876148 leather brown
    static let eqCamel        = Color(red: 0.722, green: 0.565, blue: 0.427)  // #B8906D camel
    static let eqStraw        = Color(red: 0.847, green: 0.714, blue: 0.565)  // #D8B690 warm straw
    static let eqLinen        = Color(red: 0.980, green: 0.969, blue: 0.953)  // #FAF7F3 linen
    static let eqParchment    = Color(red: 0.961, green: 0.945, blue: 0.918)  // #F5F1EA parchment
    static let eqTaupe        = Color(red: 0.859, green: 0.831, blue: 0.792)  // #DBD4CA taupe/stone
    static let eqMuted        = Color(red: 0.390, green: 0.345, blue: 0.306)  // #634F4E readable warm gray

    // Green accent — used sparingly
    static let eqForest       = Color(red: 0.188, green: 0.318, blue: 0.212)  // #305136 deep forest
    static let eqSage         = Color(red: 0.380, green: 0.514, blue: 0.392)  // #618364 sage green
    static let eqMoss         = Color(red: 0.545, green: 0.647, blue: 0.545)  // #8BA58B light moss

    // Legacy aliases — keeps existing view references compiling
    static let eqSaddleBrown  = Color.eqLeather
    static let eqChocolate    = Color.eqCamel
    static let eqSandyBrown   = Color.eqStraw
    static let eqDarkBrown    = Color.eqBark
    static let eqCream        = Color.eqParchment
    static let eqWarmWhite    = Color.eqLinen
    static let eqLightTan     = Color.eqTaupe
    static let eqMutedBrown   = Color.eqLeather.opacity(0.12)
}

// MARK: - Typography  (Avenir Next — clean geometric premium)

extension Font {
    // Primary brand typeface: Avenir Next
    static func eqFont(_ size: CGFloat, weight: Weight = .regular) -> Font {
        let name: String
        switch weight {
        case .black, .heavy:           name = "AvenirNext-Heavy"
        case .bold:                    name = "AvenirNext-Bold"
        case .semibold:                name = "AvenirNext-DemiBold"
        case .medium:                  name = "AvenirNext-Medium"
        case .light, .ultraLight, .thin: name = "AvenirNext-UltraLight"
        default:                       name = "AvenirNext-Regular"
        }
        return .custom(name, size: size)
    }

    // Drop-in replacement for all eqSerif(style:weight:) call sites
    static func eqSerif(_ style: Font.TextStyle, weight: Font.Weight = .regular) -> Font {
        let size: CGFloat
        switch style {
        case .largeTitle:  size = 34
        case .title:       size = 28
        case .title2:      size = 22
        case .title3:      size = 19
        case .headline:    size = 17
        case .body:        size = 15
        case .callout:     size = 14
        case .subheadline: size = 13
        case .footnote:    size = 12
        case .caption:     size = 11
        case .caption2:    size = 10
        @unknown default:  size = 15
        }
        return eqFont(size, weight: weight)
    }

    // Legacy named fonts
    static let eqDisplayTitle  = Font.eqFont(34, weight: .bold)
    static let eqTitle         = Font.eqFont(22, weight: .bold)
    static let eqSectionHeader = Font.eqFont(11, weight: .semibold)
}

// MARK: - Spacing & Radius

enum EQSpacing {
    static let xs: CGFloat  = 4
    static let sm: CGFloat  = 8
    static let md: CGFloat  = 16
    static let lg: CGFloat  = 24
    static let xl: CGFloat  = 32
    static let xxl: CGFloat = 48
}

enum EQRadius {
    static let sm: CGFloat   = 8
    static let md: CGFloat   = 12
    static let lg: CGFloat   = 16
    static let xl: CGFloat   = 24
    static let pill: CGFloat = 50
}

// MARK: - Gradient

extension LinearGradient {
    // Hero: deep bark to leather — editorial, natural
    static let eqBrown = LinearGradient(
        colors: [Color.eqBark, Color(red: 0.290, green: 0.192, blue: 0.137)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    // Warm hero alternative
    static let eqHero = LinearGradient(
        colors: [Color.eqBark, Color.eqLeather],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    // Card subtle
    static let eqCard = LinearGradient(
        colors: [Color.eqLinen, Color.eqParchment],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    // Green accent gradient
    static let eqGreen = LinearGradient(
        colors: [Color.eqForest, Color.eqSage],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

// MARK: - Shadow

struct EQShadow: ViewModifier {
    var radius: CGFloat = 8
    var y: CGFloat = 4
    var opacity: Double = 0.06

    func body(content: Content) -> some View {
        content
            .shadow(color: .eqInk.opacity(opacity), radius: radius, x: 0, y: y)
    }
}

extension View {
    func eqShadow(radius: CGFloat = 8, y: CGFloat = 4, opacity: Double = 0.06) -> some View {
        modifier(EQShadow(radius: radius, y: y, opacity: opacity))
    }
}

// MARK: - Navigation Appearance

struct EQNavigationAppearance: ViewModifier {
    func body(content: Content) -> some View {
        content
            .toolbarBackground(Color.eqInk, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
    }
}

extension View {
    func eqNavAppearance() -> some View {
        modifier(EQNavigationAppearance())
    }
}

// MARK: - Event Type Helpers

extension String {
    var eventTypeColor: Color {
        switch self {
        case "horse_show":      return Color.eqLeather
        case "vet_appointment": return Color.eqForest
        case "farrier":         return Color.eqCamel
        case "training":        return Color.eqSage
        case "lesson":          return Color.eqForest
        default:                return Color.eqMuted
        }
    }

    var eventTypeIcon: String {
        switch self {
        case "horse_show":      return "rosette"
        case "vet_appointment": return "cross.case.fill"
        case "farrier":         return "hammer.fill"
        case "training":        return "figure.run"
        case "lesson":          return "graduationcap.fill"
        default:                return "calendar"
        }
    }

    var eventTypeLabel: String {
        switch self {
        case "horse_show":      return "Horse Show"
        case "vet_appointment": return "Vet Appt"
        case "farrier":         return "Farrier"
        case "training":        return "Training"
        case "lesson":          return "Lesson"
        default:                return "Other"
        }
    }

    var listingTypeLabel: String {
        switch self {
        case "horse":     return "Horse"
        case "tack":      return "Tack"
        case "equipment": return "Equipment"
        case "trailer":   return "Trailer"
        default:          return "Other"
        }
    }
}

// MARK: - Haptics

struct HapticFeedback {
    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .light) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }
    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
    static func selection() {
        UISelectionFeedbackGenerator().selectionChanged()
    }
}

// MARK: - Spring Presets

extension Animation {
    /// Snappy spring for interactive elements (button presses, row taps)
    static let eqSnap = Animation.spring(response: 0.28, dampingFraction: 0.7)
    /// Smooth spring for content transitions (screen loads, sheet appearances)
    static let eqSmooth = Animation.spring(response: 0.42, dampingFraction: 0.82)
}
