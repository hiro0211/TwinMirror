import SwiftUI

struct HomeView: View {
    @State private var isComposeShown = false

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Gradients.background.ignoresSafeArea()

                VStack(spacing: Theme.Spacing.l) {
                    Spacer()

                    VStack(spacing: Theme.Spacing.s) {
                        Text("Twin Mirror")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(Theme.Colors.textSecondary)
                            .tracking(4)

                        Text("2人の写真で、\n未来の子どもに会う。")
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                            .multilineTextAlignment(.center)
                            .foregroundStyle(Theme.Colors.textPrimary)
                            .padding(.horizontal, Theme.Spacing.m)
                    }

                    Text("写真2枚から、AIがあなたとパートナーの\n未来の子どもを描きます。")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)

                    Spacer()

                    HeroIllustration()
                        .frame(height: 180)

                    Spacer()

                    GlassButton(isProminent: true, action: {
                        isComposeShown = true
                    }) {
                        Text("2人の写真で子どもを見る →")
                    }
                    .padding(.horizontal, Theme.Spacing.l)

                    LegalLinks()
                        .padding(.top, Theme.Spacing.s)
                        .padding(.bottom, Theme.Spacing.m)
                }
            }
            .navigationDestination(isPresented: $isComposeShown) {
                ComposeView()
            }
        }
    }
}

private struct HeroIllustration: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(Theme.Gradients.ctaButton)
                .frame(width: 140, height: 140)
                .blur(radius: 20)
                .opacity(0.4)

            HStack(spacing: -16) {
                ParentBubble(color: Theme.Colors.accent, symbol: "person.fill")
                ParentBubble(color: Theme.Colors.primary, symbol: "person.fill")
            }
        }
    }
}

private struct ParentBubble: View {
    let color: Color
    let symbol: String

    var body: some View {
        ZStack {
            Circle()
                .fill(color.opacity(0.25))
                .frame(width: 110, height: 110)
            Image(systemName: symbol)
                .font(.system(size: 50))
                .foregroundStyle(color)
        }
        .glassEffect(.regular.tint(color.opacity(0.3)), in: .circle)
    }
}

private struct LegalLinks: View {
    var body: some View {
        HStack(spacing: Theme.Spacing.m) {
            Link("利用規約", destination: AppConfig.termsURL)
            Text("・").foregroundStyle(Theme.Colors.textSecondary)
            Link("プライバシーポリシー", destination: AppConfig.privacyURL)
        }
        .font(.system(size: 12))
        .foregroundStyle(Theme.Colors.textSecondary)
    }
}

#Preview {
    HomeView()
}
