import SwiftUI

struct ResultView: View {
    @State private var viewModel: ResultViewModel

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

            TabView(selection: .constant(result.bestIndex)) {
                ForEach(Array(result.images.enumerated()), id: \.offset) { index, image in
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.large))
                        .padding(Theme.Spacing.m)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .frame(maxHeight: 480)

            if result.usedStyle == .illustration {
                Text("（イラスト風で生成しました）")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.Colors.textSecondary)
            }

            HStack(spacing: Theme.Spacing.m) {
                GlassButton(tint: Theme.Colors.accent, action: {
                    Task { await viewModel.saveCurrent() }
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
                ForEach(BabyGender.allCases, id: \.self) { g in
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
