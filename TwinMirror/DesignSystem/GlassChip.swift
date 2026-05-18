import SwiftUI
import UIKit

struct GlassChip: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        } label: {
            Text(title)
                .font(.system(size: 15, weight: isSelected ? .semibold : .medium))
                .foregroundStyle(isSelected ? .white : Theme.Colors.textPrimary)
                .padding(.horizontal, Theme.Spacing.m)
                .padding(.vertical, Theme.Spacing.s + 2)
                .background {
                    if reduceTransparency {
                        Capsule()
                            .fill(isSelected ? Theme.Colors.primary : Color.white.opacity(0.6))
                    }
                }
                .glassEffect(
                    isSelected
                        ? .regular.tint(Theme.Colors.primary).interactive()
                        : .regular.tint(.white.opacity(0.4)).interactive(),
                    in: .capsule
                )
        }
    }
}

#Preview {
    ZStack {
        Theme.Gradients.background.ignoresSafeArea()
        HStack(spacing: 12) {
            GlassChip(title: "女の子", isSelected: false, action: {})
            GlassChip(title: "男の子", isSelected: false, action: {})
            GlassChip(title: "おまかせ", isSelected: true, action: {})
        }
        .padding()
    }
}
