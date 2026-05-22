import SwiftUI
import UIKit

/// オンボーディングアンケート用の選択肢カード。
/// 白背景・薄影・選択時は `primaryDeep` の枠線とチェック ✔ を表示する。
/// `ComposeView` の `ModeCard` と視覚的に揃えている。
struct SurveyOptionCard: View {
    let title: String
    let iconName: String?
    let isSelected: Bool
    let action: () -> Void

    init(
        title: String,
        iconName: String? = nil,
        isSelected: Bool,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.iconName = iconName
        self.isSelected = isSelected
        self.action = action
    }

    var body: some View {
        Button {
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            action()
        } label: {
            HStack(spacing: Theme.Spacing.m) {
                if let iconName {
                    Image(systemName: iconName)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(isSelected ? Theme.Colors.primaryDeep : Theme.Colors.accent)
                        .frame(width: 28)
                }
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(isSelected ? Theme.Colors.primaryDeep : Theme.Colors.textSecondary.opacity(0.35))
            }
            .padding(Theme.Spacing.m)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: Theme.Radius.medium)
                    .fill(Color.white)
                RoundedRectangle(cornerRadius: Theme.Radius.medium)
                    .strokeBorder(
                        isSelected ? Theme.Colors.primaryDeep : Color.clear,
                        lineWidth: 2
                    )
            }
            .shadow(color: .black.opacity(isSelected ? 0.10 : 0.06), radius: 10, y: 2)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ZStack {
        Theme.Gradients.background.ignoresSafeArea()
        VStack(spacing: Theme.Spacing.s) {
            SurveyOptionCard(title: "25〜34歳", iconName: nil, isSelected: true, action: {})
            SurveyOptionCard(title: "SNS（Instagram / TikTok / X）", iconName: "person.2.wave.2.fill", isSelected: false, action: {})
            SurveyOptionCard(title: "パートナーとの未来の子どもを想像したい", iconName: "heart.fill", isSelected: false, action: {})
        }
        .padding()
    }
}
