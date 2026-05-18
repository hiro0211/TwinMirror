import SwiftUI
import UIKit

struct GlassButton<Label: View>: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    let action: () -> Void
    let tint: Color
    let isProminent: Bool
    let isEnabled: Bool
    @ViewBuilder let label: () -> Label

    init(
        tint: Color = Theme.Colors.primary,
        isProminent: Bool = false,
        isEnabled: Bool = true,
        action: @escaping () -> Void,
        @ViewBuilder label: @escaping () -> Label
    ) {
        self.tint = tint
        self.isProminent = isProminent
        self.isEnabled = isEnabled
        self.action = action
        self.label = label
    }

    var body: some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            action()
        } label: {
            label()
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, Theme.Spacing.l)
                .padding(.vertical, Theme.Spacing.m)
                .frame(maxWidth: .infinity)
                .background {
                    if reduceTransparency {
                        RoundedRectangle(cornerRadius: Theme.Radius.large)
                            .fill(isProminent ? tint : tint.opacity(0.85))
                    }
                }
                .glassEffect(
                    isProminent ? .regular.tint(tint).interactive() : .regular.tint(tint.opacity(0.6)).interactive(),
                    in: .rect(cornerRadius: Theme.Radius.large)
                )
        }
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1.0 : 0.5)
    }
}

#Preview {
    ZStack {
        Theme.Gradients.background.ignoresSafeArea()
        VStack(spacing: 16) {
            GlassButton(isProminent: true, action: {}) {
                Text("2人の写真で赤ちゃんを見る →")
            }
            GlassButton(tint: Theme.Colors.accent, action: {}) {
                Text("読み込む")
            }
            GlassButton(isProminent: true, isEnabled: false, action: {}) {
                Text("生成する")
            }
        }
        .padding()
    }
}
