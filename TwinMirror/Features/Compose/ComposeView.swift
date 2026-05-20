import SwiftUI
import PhotosUI

struct ComposeView: View {
    @State private var viewModel = ComposeViewModel()
    @State private var fatherPickerItem: PhotosPickerItem?
    @State private var motherPickerItem: PhotosPickerItem?
    @State private var navigateToResult = false
    @State private var generationRequest: GenerationRequest?
    @State private var showAIConsentSheet = false
    @State private var showUsageLimitAlert = false

    @AppStorage("twinmirror.consent.ai") private var hasConsentedToAI = false

    private let usageLimiter = UsageLimiter.shared

    var body: some View {
        ZStack {
            Theme.Gradients.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: Theme.Spacing.l) {
                    titleSection
                    photoCardsSection
                    ageSection
                    genderSection
                    instructionsSection
                    disclaimerSection
                    usageBadge
                    generateButton
                }
                .padding(.horizontal, Theme.Spacing.l)
                .padding(.vertical, Theme.Spacing.m)
            }

            if viewModel.isProcessingFace {
                ProgressView("顔を解析中…")
                    .padding()
                    .background(.regularMaterial, in: .rect(cornerRadius: 12))
            }
        }
        .navigationTitle("子どもを生成")
        .navigationBarTitleDisplayMode(.inline)
        .alert("エラー", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .alert("本日の生成上限に達しました", isPresented: $showUsageLimitAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("コスト管理のため、1日あたり \(UsageLimiter.dailyLimit) 回までご利用いただけます。明日また使ってみてください。")
        }
        .sheet(isPresented: $showAIConsentSheet) {
            AIConsentSheet(
                onAccept: {
                    hasConsentedToAI = true
                    showAIConsentSheet = false
                    proceedToGenerate()
                },
                onDecline: {
                    showAIConsentSheet = false
                }
            )
        }
        .onChange(of: fatherPickerItem) { _, newValue in
            Task { await loadImage(from: newValue, slot: .father) }
        }
        .onChange(of: motherPickerItem) { _, newValue in
            Task { await loadImage(from: newValue, slot: .mother) }
        }
        .navigationDestination(isPresented: $navigateToResult) {
            if let req = generationRequest,
               let father = viewModel.fatherImage,
               let mother = viewModel.motherImage {
                ResultView(
                    initialRequest: req,
                    fatherImage: father,
                    motherImage: mother
                )
            }
        }
    }

    private var titleSection: some View {
        VStack(spacing: Theme.Spacing.xs) {
            Text("2人の写真を選んでください")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.Colors.textPrimary)
            Text("正面を向いた、目・鼻・口がはっきり見える写真をご利用ください")
                .font(.system(size: 13))
                .foregroundStyle(Theme.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
    }

    private var photoCardsSection: some View {
        HStack(spacing: Theme.Spacing.m) {
            ParentPhotoCard(
                label: "お父さん",
                image: viewModel.fatherImage,
                pickerItem: $fatherPickerItem,
                onClear: { viewModel.clear(slot: .father) }
            )
            ParentPhotoCard(
                label: "お母さん",
                image: viewModel.motherImage,
                pickerItem: $motherPickerItem,
                onClear: { viewModel.clear(slot: .mother) }
            )
        }
    }

    private var ageSection: some View {
        @Bindable var vm = viewModel
        return VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Text("年齢")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.Colors.textPrimary)
            AgeRulerPicker(age: $vm.age)
        }
    }

    private var genderSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Text("性別")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.Colors.textPrimary)
            HStack(spacing: Theme.Spacing.s) {
                ForEach(ChildGender.allCases, id: \.self) { g in
                    GlassChip(
                        title: g.displayName,
                        isSelected: viewModel.gender == g,
                        action: { viewModel.gender = g }
                    )
                }
                Spacer()
            }
        }
    }

    private var instructionsSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Label("使い方", systemImage: "book.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.Colors.textPrimary)
            BulletText("1人ずつ別の写真を選んでください")
            BulletText("目・鼻・口がはっきり見える写真")
            BulletText("正面を向いた顔の写真")
        }
        .padding(Theme.Spacing.m)
        .glassEffect(.regular.tint(.white.opacity(0.7)), in: .rect(cornerRadius: Theme.Radius.medium))
    }

    private var disclaimerSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Label("ご利用について", systemImage: "exclamationmark.triangle.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.orange)
            BulletText("18歳以上の方の写真のみ使用可")
            BulletText("生成結果は娯楽目的で、実際の遺伝的予測ではありません")
            BulletText("画像は生成のためにGoogle Geminiに送信されます")
        }
        .padding(Theme.Spacing.m)
        .glassEffect(.regular.tint(Theme.Colors.cream.opacity(0.85)), in: .rect(cornerRadius: Theme.Radius.medium))
    }

    private var usageBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: "gauge.medium")
                .font(.system(size: 12, weight: .semibold))
            Text("本日の残り生成回数: \(usageLimiter.remainingToday) / \(UsageLimiter.dailyLimit)")
                .font(.system(size: 12, weight: .medium))
        }
        .foregroundStyle(Theme.Colors.textSecondary)
        .padding(.horizontal, Theme.Spacing.m)
        .padding(.vertical, Theme.Spacing.s)
        .glassEffect(.regular.tint(.white.opacity(0.5)), in: .capsule)
    }

    private var generateButton: some View {
        GlassButton(
            isProminent: true,
            isEnabled: viewModel.canGenerate,
            action: handleGenerateTapped
        ) {
            Text("子どもを生成する")
        }
        .padding(.top, Theme.Spacing.s)
    }

    private func handleGenerateTapped() {
        guard usageLimiter.canGenerate else {
            showUsageLimitAlert = true
            return
        }
        guard hasConsentedToAI else {
            showAIConsentSheet = true
            return
        }
        proceedToGenerate()
    }

    private func proceedToGenerate() {
        guard usageLimiter.tryConsume() else {
            showUsageLimitAlert = true
            return
        }
        if let req = viewModel.buildGenerationRequest() {
            generationRequest = req
            navigateToResult = true
        }
    }

    private func loadImage(from item: PhotosPickerItem?, slot: ComposeViewModel.ParentSlot) async {
        guard let item else { return }
        do {
            if let data = try await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                await viewModel.setImage(image, for: slot)
            }
        } catch {
            await MainActor.run { viewModel.errorMessage = error.localizedDescription }
        }
    }
}

private struct ParentPhotoCard: View {
    let label: String
    let image: UIImage?
    @Binding var pickerItem: PhotosPickerItem?
    let onClear: () -> Void

    var body: some View {
        VStack(spacing: Theme.Spacing.s) {
            ZStack {
                RoundedRectangle(cornerRadius: Theme.Radius.medium)
                    .fill(Color.white.opacity(0.5))
                    .aspectRatio(1, contentMode: .fit)

                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .clipShape(Circle())
                        .padding(Theme.Spacing.m)
                } else {
                    Image(systemName: "person.fill")
                        .font(.system(size: 50))
                        .foregroundStyle(Theme.Colors.textSecondary.opacity(0.4))
                }
            }
            .glassEffect(.regular.tint(.white.opacity(0.2)), in: .rect(cornerRadius: Theme.Radius.medium))
            .overlay(alignment: .topTrailing) {
                if image != nil {
                    Button(action: onClear) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(.white, .black.opacity(0.6))
                            .frame(width: 44, height: 44)
                            .contentShape(Circle())
                    }
                    .padding(Theme.Spacing.s)
                    .accessibilityLabel("写真を削除")
                }
            }

            Text(label)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.Colors.textPrimary)

            PhotosPicker(selection: $pickerItem, matching: .images) {
                Text(image == nil ? "読み込む" : "変更")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, Theme.Spacing.m)
                    .padding(.vertical, Theme.Spacing.s)
                    .glassEffect(.regular.tint(Theme.Colors.accent.opacity(0.7)).interactive(), in: .capsule)
            }
        }
    }
}

private struct BulletText: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            Text("•").foregroundStyle(Theme.Colors.textSecondary)
            Text(text)
                .font(.system(size: 13))
                .foregroundStyle(Theme.Colors.textPrimary)
        }
    }
}

/// Apple App Review Guideline 5.1.2(i) 準拠の AI 送信同意シート。
/// 初回生成前に明示的同意を取得する。
private struct AIConsentSheet: View {
    let onAccept: () -> Void
    let onDecline: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.l) {
            HStack {
                Image(systemName: "shield.lefthalf.filled")
                    .font(.system(size: 28))
                    .foregroundStyle(Theme.Colors.accent)
                Text("AI処理についてのご確認")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.Colors.textPrimary)
            }
            .padding(.top, Theme.Spacing.l)

            VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                Text("子ども画像の生成にあたり、選択された2枚の写真は次の処理を行います。")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.Colors.textPrimary)

                BulletText("Google LLC の画像生成API（Gemini）に送信されます")
                BulletText("生成リクエストにのみ使用され、当アプリの開発者サーバーには保存されません")
                BulletText("18歳未満の方の写真は使用しないでください")
                BulletText("詳細はプライバシーポリシーをご確認ください")
            }

            Link("プライバシーポリシーを開く", destination: AppConfig.privacyURL)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.Colors.accent)

            Spacer()

            VStack(spacing: Theme.Spacing.s) {
                GlassButton(isProminent: true, action: onAccept) {
                    Text("同意して続ける")
                }
                Button("キャンセル", action: onDecline)
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
            .padding(.bottom, Theme.Spacing.l)
        }
        .padding(.horizontal, Theme.Spacing.l)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

#Preview {
    NavigationStack {
        ComposeView()
    }
}
