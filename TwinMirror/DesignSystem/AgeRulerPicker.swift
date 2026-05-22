import SwiftUI

/// 0〜20歳を 1歳刻みで横スクロール選択するルーラー型ピッカー。
///
/// - iOS 26 `.scrollPosition(id:)` + `.scrollTargetBehavior(.viewAligned)` でスナップ。
/// - `.sensoryFeedback(.selection, trigger:)` でティック切替ごとに触覚（実機のみ）。
/// - Liquid Glass の `.glassEffect(...)` でデザインシステムと統一。
struct AgeRulerPicker: View {
    @Binding var age: ChildAge

    var minYears: Int = ChildAge.minYears
    var maxYears: Int = ChildAge.maxYears

    @State private var scrolledYear: Int?
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    private let tickSpacing: CGFloat = 24
    private let rulerHeight: CGFloat = 60
    private let indicatorHeight: CGFloat = 36

    var body: some View {
        VStack(spacing: Theme.Spacing.m) {
            ageNumberDisplay
            ruler
        }
        .onAppear {
            if scrolledYear == nil { scrolledYear = age.years }
        }
        .onChange(of: scrolledYear) { _, new in
            guard let new else { return }
            if new != age.years {
                age = ChildAge(years: new)
            }
        }
        .onChange(of: age.years) { _, new in
            if scrolledYear != new { scrolledYear = new }
        }
        .sensoryFeedback(.selection, trigger: age.years)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("子どもの年齢")
        .accessibilityValue(age.displayName)
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment:
                age = ChildAge.clamped(years: age.years + 1)
                scrolledYear = age.years
            case .decrement:
                age = ChildAge.clamped(years: age.years - 1)
                scrolledYear = age.years
            @unknown default:
                break
            }
        }
    }

    private var ageNumberDisplay: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text("\(age.years)")
                .font(.system(size: 56, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.Colors.textPrimary)
                .contentTransition(.numericText(value: Double(age.years)))
                .animation(.snappy(duration: 0.18), value: age.years)
            Text("歳")
                .font(.system(size: 24, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var ruler: some View {
        GeometryReader { geo in
            // 中央指標と最初/最後のティック中心を揃えるための左右余白。
            // `.contentMargins(for: .scrollContent)` に渡すことで、空白 view を
            // LazyHStack 内に入れて scrollTargetLayout の snap 候補に混ぜる事故を防ぐ。
            let halfWidth = geo.size.width / 2
            let edgePad = max(0, halfWidth - tickSpacing / 2)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(minYears...maxYears, id: \.self) { y in
                        TickMark(year: y, isMajor: y.isMultiple(of: 5))
                            .frame(width: tickSpacing, height: rulerHeight)
                            .id(y)
                    }
                }
                .scrollTargetLayout()
            }
            .contentMargins(.horizontal, edgePad, for: .scrollContent)
            .scrollPosition(id: $scrolledYear, anchor: .center)
            .scrollTargetBehavior(.viewAligned(limitBehavior: .always))
            .overlay(centerIndicator)
        }
        .frame(height: rulerHeight)
        .background {
            if reduceTransparency {
                Capsule().fill(Color.white.opacity(0.75))
            }
        }
        .glassEffect(
            .regular.tint(.white.opacity(0.5)).interactive(),
            in: .capsule
        )
    }

    private var centerIndicator: some View {
        Capsule()
            .fill(Theme.Colors.primary)
            .frame(width: 4, height: indicatorHeight)
            .shadow(color: Theme.Colors.primary.opacity(0.35), radius: 6)
            .allowsHitTesting(false)
    }
}

private struct TickMark: View {
    let year: Int
    let isMajor: Bool

    var body: some View {
        VStack(spacing: 4) {
            Spacer(minLength: 0)
            Capsule()
                .fill(tickColor)
                .frame(width: tickWidth, height: tickHeight)
            if isMajor {
                Text("\(year)")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .monospacedDigit()
            } else {
                Spacer(minLength: 0).frame(height: 13)
            }
            Spacer(minLength: 0)
        }
    }

    private var tickWidth: CGFloat { isMajor ? 2 : 1.5 }
    private var tickHeight: CGFloat { isMajor ? 24 : 14 }
    private var tickColor: Color {
        isMajor
            ? Theme.Colors.textPrimary.opacity(0.7)
            : Theme.Colors.textSecondary.opacity(0.55)
    }
}

#Preview {
    @Previewable @State var age: ChildAge = .default
    return ZStack {
        Theme.Gradients.background.ignoresSafeArea()
        VStack(spacing: Theme.Spacing.l) {
            AgeRulerPicker(age: $age)
                .padding(.horizontal, Theme.Spacing.l)

            Text("選択中: \(age.displayName) — bucket: \(String(describing: age.bucket))")
                .font(.system(size: 13, design: .rounded))
                .foregroundStyle(Theme.Colors.textSecondary)
        }
    }
}
