import SwiftUI

struct EQTextField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    var icon: String? = nil
    var isSecure: Bool = false
    var keyboard: UIKeyboardType = .default

    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: EQSpacing.xs) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.eqDarkBrown)

            HStack(spacing: EQSpacing.sm) {
                if let icon {
                    Image(systemName: icon)
                        .font(.body)
                        .foregroundStyle(isFocused ? Color.eqSaddleBrown : Color.eqMuted)
                        .frame(width: 20)
                }

                if isSecure {
                    SecureField(placeholder, text: $text)
                        .focused($isFocused)
                        .font(.body)
                        .foregroundStyle(Color.eqDarkBrown)
                } else {
                    TextField(placeholder, text: $text)
                        .focused($isFocused)
                        .font(.body)
                        .foregroundStyle(Color.eqDarkBrown)
                        .keyboardType(keyboard)
                        .autocorrectionDisabled()
                }
            }
            .padding(.horizontal, EQSpacing.md)
            .frame(height: 50)
            .background(Color.eqCream)
            .clipShape(RoundedRectangle(cornerRadius: EQRadius.sm, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: EQRadius.sm, style: .continuous)
                    .strokeBorder(
                        isFocused ? Color.eqSaddleBrown : Color.eqLightTan,
                        lineWidth: isFocused ? 1.5 : 1
                    )
            )
            .animation(.easeInOut(duration: 0.15), value: isFocused)
        }
    }
}

// MARK: - Multi-line text field

struct EQTextEditor: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    var minHeight: CGFloat = 80

    var body: some View {
        VStack(alignment: .leading, spacing: EQSpacing.xs) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.eqDarkBrown)

            ZStack(alignment: .topLeading) {
                if text.isEmpty {
                    Text(placeholder)
                        .font(.body)
                        .foregroundStyle(Color.eqMuted.opacity(0.7))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 10)
                }
                TextEditor(text: $text)
                    .font(.body)
                    .foregroundStyle(Color.eqDarkBrown)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: minHeight)
            }
            .padding(.horizontal, EQSpacing.sm)
            .padding(.vertical, EQSpacing.xs)
            .background(Color.eqCream)
            .clipShape(RoundedRectangle(cornerRadius: EQRadius.sm, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: EQRadius.sm, style: .continuous)
                    .strokeBorder(Color.eqLightTan, lineWidth: 1)
            )
        }
    }
}

// MARK: - Picker Field

struct EQPickerField: View {
    let label: String
    @Binding var selection: String
    let options: [(value: String, label: String)]
    var icon: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: EQSpacing.xs) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.eqDarkBrown)

            Menu {
                ForEach(options, id: \.value) { option in
                    Button(option.label) {
                        selection = option.value
                    }
                }
            } label: {
                HStack(spacing: EQSpacing.sm) {
                    if let icon {
                        Image(systemName: icon)
                            .font(.body)
                            .foregroundStyle(Color.eqMuted)
                            .frame(width: 20)
                    }
                    Text(options.first(where: { $0.value == selection })?.label ?? "Select…")
                        .font(.body)
                        .foregroundStyle(selection.isEmpty ? Color.eqMuted.opacity(0.7) : Color.eqDarkBrown)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption)
                        .foregroundStyle(Color.eqMuted)
                }
                .padding(.horizontal, EQSpacing.md)
                .frame(height: 50)
                .background(Color.eqCream)
                .clipShape(RoundedRectangle(cornerRadius: EQRadius.sm, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: EQRadius.sm, style: .continuous)
                        .strokeBorder(Color.eqLightTan, lineWidth: 1)
                )
            }
        }
    }
}
