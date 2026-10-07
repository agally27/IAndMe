import SwiftUI

/// Five plain words for how a moment felt. Optional, quick, and never a questionnaire.
struct FeelingPicker: View {
    @Binding var feeling: Feeling?
    @Environment(\.motion) private var motion

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("How did this feel?")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Theme.Colors.inkSecondary)
            HStack(spacing: 0) {
                ForEach(Feeling.allCases) { option in
                    let selected = feeling == option
                    Button {
                        withAnimation(motion.spring) {
                            feeling = selected ? nil : option
                        }
                    } label: {
                        VStack(spacing: 8) {
                            ZStack {
                                Circle()
                                    .fill(option.color.opacity(selected ? 1 : 0.55))
                                    .frame(width: 30, height: 30)
                                if selected {
                                    Circle()
                                        .strokeBorder(option.color, lineWidth: 2)
                                        .frame(width: 42, height: 42)
                                }
                            }
                            .frame(width: 44, height: 44)
                            .scaleEffect(selected ? 1.05 : 1)
                            Text(option.label)
                                .font(.caption2.weight(selected ? .semibold : .regular))
                                .foregroundStyle(selected ? Theme.Colors.ink : Theme.Colors.inkTertiary)
                        }
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(option.label)
                    .accessibilityAddTraits(selected ? [.isSelected] : [])
                    .accessibilityIdentifier("capture.feeling.\(option.label.lowercased())")
                }
            }
        }
        .sensoryFeedback(.selection, trigger: feeling)
    }
}
