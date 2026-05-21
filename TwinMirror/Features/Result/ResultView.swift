import SwiftUI

struct ResultView: View {
    @State private var viewModel: ResultViewModel
    @State private var selectedIndex: Int = 0

    init(initialRequest: GenerationRequest, fatherImage: UIImage, motherImage: UIImage) {
        _viewModel = State(initialValue: ResultViewModel(
            initialRequest: initialRequest,
            fatherImage: fatherImage,
            motherImage: motherImage
        ))
    }

    var body: some View {
        ZStack {
            Theme.Gradients.background.ignoresSafeArea()

            switch viewModel.phase {
            case .loading:
                LoadingMorphView(fatherImage: viewModel.fatherImage, motherImage: viewModel.motherImage)
            case .done(let result):
                doneBody(result: result)
            case .failed(let message):
                failedBody(message: message)
            }

            if let toast = viewModel.savedToast {
                VStack {
                    Spacer()
                    Text(toast)
                        .font(.system(size: 14, weight: .semibold))
                        .padding(.horizontal, Theme.Spacing.l)
                        .padding(.vertical, Theme.Spacing.s)
                        .background(.regularMaterial, in: .capsule)
                        .padding(.bottom, Theme.Spacing.xl)
                }
            }
        }
        .navigationTitle("結果")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.generate() }
    }

    @ViewBuilder
    private func doneBody(result: GenerationResult) -> some View {
        VStack(spacing: Theme.Spacing.l) {
            Spacer()

            TabView(selection: $selectedIndex) {
                ForEach(Array(result.images.enumerated()), id: \.offset) { index, image in
                    VStack(spacing: Theme.Spacing.s) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.large))
                        if result.ratios.indices.contains(index), result.ratios.count > 1 {
                            BlendRatioBadge(
                                ratio: result.ratios[index],
                                fatherImage: viewModel.fatherImage,
                                motherImage: viewModel.motherImage
                            )
                        }
                    }
                    .padding(Theme.Spacing.m)
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .frame(maxHeight: 560)
            .onAppear {
                if !result.images.indices.contains(selectedIndex) {
                    selectedIndex = result.bestIndex
                }
            }
            .onChange(of: result.images.count) { _, _ in
                selectedIndex = result.bestIndex
            }

            if result.usedStyle == .illustration {
                Text("（イラスト風で生成しました）")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.Colors.textSecondary)
            }

            HStack(spacing: Theme.Spacing.m) {
                GlassButton(tint: Theme.Colors.accent, action: {
                    Task { await viewModel.saveCurrent(at: selectedIndex) }
                }) {
                    Label("保存", systemImage: "square.and.arrow.down")
                }

                GlassButton(isProminent: true, action: {
                    Task { await viewModel.generate() }
                }) {
                    Label("もう一度", systemImage: "arrow.clockwise")
                }
            }
            .padding(.horizontal, Theme.Spacing.l)

            HStack(spacing: Theme.Spacing.s) {
                ForEach(ChildGender.allCases, id: \.self) { g in
                    GlassChip(
                        title: g.displayName,
                        isSelected: viewModel.gender == g,
                        action: {
                            Task { await viewModel.regenerate(with: g) }
                        }
                    )
                }
            }
            .padding(.bottom, Theme.Spacing.l)
        }
    }

    @ViewBuilder
    private func failedBody(message: String) -> some View {
        VStack(spacing: Theme.Spacing.l) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundStyle(.orange)
            Text("生成できませんでした")
                .font(.system(size: 20, weight: .semibold, design: .rounded))
            Text(message)
                .font(.system(size: 13))
                .foregroundStyle(Theme.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.Spacing.l)

            GlassButton(isProminent: true, action: {
                Task { await viewModel.generate() }
            }) {
                Text("もう一度試す")
            }
            .padding(.horizontal, Theme.Spacing.l)
        }
        .padding()
    }
}

private struct BlendRatioBadge: View {
    let ratio: BlendRatio
    let fatherImage: UIImage
    let motherImage: UIImage

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(ratio.displayLabel)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.Colors.textPrimary)
            ParentBar(
                avatar: fatherImage,
                label: "お父さん",
                percent: ratio.fatherPercent,
                barColor: Color(red: 0.55, green: 0.70, blue: 1.0)
            )
            ParentBar(
                avatar: motherImage,
                label: "お母さん",
                percent: ratio.motherPercent,
                barColor: Color(red: 1.0, green: 0.55, blue: 0.75)
            )
        }
        .padding(.horizontal, Theme.Spacing.m)
        .padding(.vertical, Theme.Spacing.s)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular.tint(.white.opacity(0.7)), in: .rect(cornerRadius: Theme.Radius.medium))
    }
}

private struct ParentBar: View {
    let avatar: UIImage
    let label: String
    let percent: Int
    let barColor: Color

    var body: some View {
        HStack(spacing: 8) {
            Image(uiImage: avatar)
                .resizable()
                .scaledToFill()
                .frame(width: 22, height: 22)
                .clipShape(Circle())
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.black.opacity(0.08))
                    Capsule()
                        .fill(barColor)
                        .frame(width: geo.size.width * CGFloat(percent) / 100)
                }
            }
            .frame(height: 6)
            Text("\(percent)")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.Colors.textPrimary)
                .frame(width: 28, alignment: .trailing)
        }
        .accessibilityLabel("\(label) \(percent)パーセント")
    }
}
