import SwiftUI

struct HistoryEmptyState: View {
    var body: some View {
        VStack(spacing: Theme.Spacing.m) {
            Image(systemName: "photo.stack")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(Theme.Colors.primary)
                .padding(Theme.Spacing.l)
                .glassEffect(.regular.tint(Theme.Colors.primary.opacity(0.15)), in: .circle)

            Text("まだ生成画像はありません")
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.Colors.textPrimary)

            Text("ホームから最初の1枚を作ってみましょう")
                .font(.system(size: 13))
                .foregroundStyle(Theme.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, Theme.Spacing.l)
    }
}

#Preview {
    HistoryEmptyState()
}
