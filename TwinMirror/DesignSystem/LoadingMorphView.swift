import SwiftUI

struct LoadingMorphView: View {
    let fatherImage: UIImage
    let motherImage: UIImage

    @State private var phase: Int = 0
    @State private var startDate = Date()

    private let phaseMessages = [
        "2人の顔を読み取り中…",
        "特徴を解析中…",
        "未来の姿を描いています…",
        "もうすぐ会えます…"
    ]

    var body: some View {
        ZStack {
            Theme.Gradients.background.ignoresSafeArea()

            VStack(spacing: Theme.Spacing.xl) {
                GlassEffectContainer(spacing: -40) {
                    HStack(spacing: morphSpacing) {
                        ParentMorphBubble(image: fatherImage, scale: bubbleScale(0))
                            .glassEffectID("father", in: namespace)
                        ParentMorphBubble(image: motherImage, scale: bubbleScale(1))
                            .glassEffectID("mother", in: namespace)
                    }
                }
                .frame(height: 180)

                VStack(spacing: Theme.Spacing.s) {
                    Text(currentMessage)
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.Colors.textPrimary)
                        .transition(.opacity)
                        .id(currentMessage)

                    ProgressView()
                        .controlSize(.regular)
                        .tint(Theme.Colors.primary)
                }
            }
            .padding()
        }
        .onAppear { startDate = Date() }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 250_000_000)
                let elapsed = Date().timeIntervalSince(startDate)
                let newPhase = min(phaseMessages.count - 1, Int(elapsed / 4))
                if newPhase != phase {
                    withAnimation(.easeInOut(duration: 0.6)) { phase = newPhase }
                }
            }
        }
    }

    @Namespace private var namespace

    private var currentMessage: String {
        phaseMessages[min(phase, phaseMessages.count - 1)]
    }

    private var morphSpacing: CGFloat {
        switch phase {
        case 0: return 16
        case 1: return 0
        case 2: return -40
        default: return -60
        }
    }

    private func bubbleScale(_ index: Int) -> CGFloat {
        switch phase {
        case 0: return 1.0
        case 1: return 1.05
        case 2: return 1.1
        default: return 1.15
        }
    }
}

private struct ParentMorphBubble: View {
    let image: UIImage
    let scale: CGFloat

    var body: some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFill()
            .frame(width: 140, height: 140)
            .clipShape(Circle())
            .scaleEffect(scale)
            .animation(.easeInOut(duration: 0.8), value: scale)
            .overlay(
                Circle().stroke(.white.opacity(0.6), lineWidth: 3)
            )
            .shadow(color: Theme.Colors.primary.opacity(0.3), radius: 20)
    }
}

#Preview {
    LoadingMorphView(
        fatherImage: UIImage(systemName: "person.crop.circle.fill")!,
        motherImage: UIImage(systemName: "person.crop.circle.fill")!
    )
}
