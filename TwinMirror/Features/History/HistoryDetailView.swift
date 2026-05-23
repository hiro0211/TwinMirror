import SwiftUI

struct HistoryDetailView: View {
    let item: HistoryItem
    let service: HistoryServicing
    let onDelete: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var image: UIImage?
    @State private var isSavingToPhotos = false
    @State private var toast: String?

    private let saveService: PhotoSaving = PhotoSaveService()

    var body: some View {
        ZStack {
            Theme.Gradients.background.ignoresSafeArea()

            VStack(spacing: Theme.Spacing.l) {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.large))
                        .shadow(color: .black.opacity(0.1), radius: 12, y: 6)
                } else {
                    RoundedRectangle(cornerRadius: Theme.Radius.large)
                        .fill(.ultraThinMaterial)
                        .frame(maxWidth: .infinity)
                        .aspectRatio(3.0 / 4.0, contentMode: .fit)
                        .overlay { ProgressView() }
                }

                metadataPanel

                Spacer(minLength: 0)

                HStack(spacing: Theme.Spacing.m) {
                    GlassButton(tint: Theme.Colors.accent, isEnabled: image != nil) {
                        Task { await saveToPhotos() }
                    } label: {
                        Label("写真に保存", systemImage: "square.and.arrow.down")
                    }

                    GlassButton(tint: .red.opacity(0.8)) {
                        onDelete()
                    } label: {
                        Label("削除", systemImage: "trash")
                    }
                }
                .padding(.horizontal, Theme.Spacing.l)
                .padding(.bottom, Theme.Spacing.l)
            }
            .padding(.top, Theme.Spacing.l)
            .padding(.horizontal, Theme.Spacing.m)

            if let toast {
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
        .task {
            if image == nil {
                let isPremium = await MainActor.run { PurchaseService.shared.isPremium }
                if let data = try? await service.imageData(
                    for: item.id,
                    variant: .original,
                    isPremium: isPremium
                ), let ui = UIImage(data: data) {
                    image = ui
                }
            }
        }
    }

    @ViewBuilder
    private var metadataPanel: some View {
        let formatter: DateFormatter = {
            let f = DateFormatter()
            f.dateStyle = .medium
            f.timeStyle = .short
            f.locale = Locale(identifier: "ja_JP")
            return f
        }()
        VStack(alignment: .leading, spacing: 6) {
            Text(formatter.string(from: item.createdAt))
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.Colors.textPrimary)
            HStack(spacing: 6) {
                if let g = item.gender { tag(g) }
                if let a = item.age { tag("\(a)歳") }
                if let m = item.mode { tag(m) }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.m)
        .glassEffect(.clear, in: .rect(cornerRadius: Theme.Radius.medium))
    }

    private func tag(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(Theme.Colors.textSecondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Color.black.opacity(0.05), in: .capsule)
    }

    private func saveToPhotos() async {
        guard let image, !isSavingToPhotos else { return }
        isSavingToPhotos = true
        defer { isSavingToPhotos = false }
        do {
            try await saveService.save(image)
            toast = "写真に保存しました"
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        } catch {
            toast = error.localizedDescription
        }
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            await MainActor.run { toast = nil }
        }
    }
}
