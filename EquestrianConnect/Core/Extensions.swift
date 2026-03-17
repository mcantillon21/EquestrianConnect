import SwiftUI

// MARK: - View Extensions

extension View {
    @ViewBuilder
    func `if`<T: View>(_ condition: Bool, transform: (Self) -> T) -> some View {
        if condition { transform(self) } else { self }
    }
}

// MARK: - Date Helpers

extension String {
    func toDisplayDate(format: String = "MMM d, yyyy") -> String {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withFullDate, .withDashSeparatorInDate]
        if let date = iso.date(from: self) {
            let df = DateFormatter()
            df.dateFormat = format
            return df.string(from: date)
        }
        // Try full ISO
        let isoFull = ISO8601DateFormatter()
        isoFull.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = isoFull.date(from: self) {
            let df = DateFormatter()
            df.dateFormat = format
            return df.string(from: date)
        }
        return self
    }

    func toDate() -> Date? {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withFullDate, .withDashSeparatorInDate]
        if let d = iso.date(from: self) { return d }
        let isoFull = ISO8601DateFormatter()
        isoFull.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return isoFull.date(from: self)
    }

    func toRelativeDate() -> String {
        guard let date = self.toDate() else { return self }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

extension Date {
    var iso8601DateString: String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withFullDate, .withDashSeparatorInDate]
        return f.string(from: self)
    }

    var iso8601String: String {
        ISO8601DateFormatter().string(from: self)
    }

    func formatted(_ format: String) -> String {
        let df = DateFormatter()
        df.dateFormat = format
        return df.string(from: self)
    }

    var isToday: Bool { Calendar.current.isDateInToday(self) }
    var isThisMonth: Bool {
        let c = Calendar.current
        return c.component(.month, from: self) == c.component(.month, from: Date()) &&
               c.component(.year, from: self) == c.component(.year, from: Date())
    }
}

// MARK: - Number Formatting

extension Double {
    var currencyString: String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.maximumFractionDigits = 0
        return f.string(from: NSNumber(value: self)) ?? "$\(Int(self))"
    }
}

// MARK: - String Helpers

extension String {
    var initials: String {
        let words = self.split(separator: " ").filter { $0.first?.isLetter ?? false }
        return words.prefix(2).compactMap { $0.first.map { String($0).uppercased() } }.joined()
    }

    var isValidEmail: Bool {
        let regex = #"^[A-Z0-9a-z._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}$"#
        return self.range(of: regex, options: .regularExpression) != nil
    }
}

// MARK: - Conditional Modifier

struct ConditionalModifier<TrueModifier: ViewModifier, FalseModifier: ViewModifier>: ViewModifier {
    let condition: Bool
    let trueModifier: TrueModifier
    let falseModifier: FalseModifier

    func body(content: Content) -> some View {
        if condition {
            content.modifier(trueModifier)
        } else {
            content.modifier(falseModifier)
        }
    }
}
