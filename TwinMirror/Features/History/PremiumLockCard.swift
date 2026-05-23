import SwiftUI

struct PremiumLockCard: View {
    let hiddenCount: Int
    let onUnlockTap: () -> Void

    var body: some View {
        VStack(spacing: Theme.Spacing.s) {
            HStack(spacing: 6) {
                Image(systemName: "lock.fill")
                Text("Premiumで無制限")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Theme.Colors.primary, in: .capsule)

            Text(headline)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
                .foregroundStyle(Theme.Colors.textPrimary)

            Text("無料では直近3件のみ表示されます。\nPremiumにすると過去すべての履歴に\nいつでもアクセスできます。")
                .font(.system(size: 12))
                .foregroundStyle(Theme.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(2)

            Button(action: onUnlockTap) {
                Text("Premiumをみる")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.glassProminent)
            .tint(Theme.Colors.primaryDeep)
            .padding(.top, 4)
        }
        .padding(Theme.Spacing.l)
        .frame(maxWidth: .infinity)
        .glassEffect(.regular.tint(.white.opacity(0.6)), in: .rect(cornerRadius: Theme.Radius.large))
    }

    private var headline: String {
        if hiddenCount > 0 {
            return "あと\(hiddenCount)件の作品を見る"
        }
        return "すべての履歴をアンロック"
    }
}

#Preview {
    PremiumLockCard(hiddenCount: 12, onUnlockTap: {})
        .padding()
        .background(Theme.Gradients.background)
}
