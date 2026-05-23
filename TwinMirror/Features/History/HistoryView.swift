import SwiftUI

struct HistoryView: View {
    @State private var viewModel: HistoryViewModel
    @State private var selectedItem: HistoryItem?
    @State private var showPaywall = false
    @State private var didAppearOnce = false
    @Namespace private var heroNamespace

    private let analytics: AnalyticsTracking

    init(
        service: HistoryServicing? = HistoryService.makeDefault(),
        analytics: AnalyticsTracking = DefaultAnalytics.shared
    ) {
        let resolved: HistoryServicing = service ?? DisabledHistoryService()
        _viewModel = State(initialValue: HistoryViewModel(
            service: resolved,
            isPremiumProvider: { MainActor.assumeIsolated { PurchaseService.shared.isPremium } }
        ))
        self.analytics = analytics
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Gradients.background.ignoresSafeArea()

                if viewModel.isLoading && viewModel.items.isEmpty {
                    ProgressView().controlSize(.large)
                } else if viewModel.isEmpty {
                    HistoryEmptyState()
                } else {
                    gridScroll
                }
            }
            .navigationTitle("履歴")
            .navigationBarTitleDisplayMode(.large)
            .tabBarMinimizeBehavior(.onScrollDown)
            .sheet(item: $selectedItem) { item in
                HistoryDetailView(
                    item: item,
                    service: viewModel.service,
                    onDelete: {
                        Task {
                            await viewModel.delete(item)
                            selectedItem = nil
                        }
                    }
                )
                .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
            .task {
                if !didAppearOnce {
                    didAppearOnce = true
                    analytics.track(.historyOpened)
                }
                await viewModel.load()
            }
            .refreshable {
                await viewModel.load()
            }
        }
    }

    private var gridScroll: some View {
        ScrollView {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 110), spacing: 4)],
                spacing: 4,
                pinnedViews: [.sectionHeaders]
            ) {
                ForEach(viewModel.sections) { section in
                    Section {
                        ForEach(section.items) { item in
                            HistoryCell(item: item, service: viewModel.service, namespace: heroNamespace)
                                .onTapGesture {
                                    selectedItem = item
                                    analytics.track(.historyItemOpened)
                                }
                                .contextMenu {
                                    Button(role: .destructive) {
                                        Task { await viewModel.delete(item) }
                                    } label: {
                                        Label("削除", systemImage: "trash")
                                    }
                                }
                        }
                    } header: {
                        SectionHeader(title: section.title)
                    }
                }

                if viewModel.freeLimitReached {
                    PremiumLockCard(hiddenCount: max(0, viewModel.totalCount - viewModel.items.count)) {
                        analytics.track(.historyPaywallTapped)
                        showPaywall = true
                    }
                    .gridCellColumns(3)
                    .padding(.top, Theme.Spacing.m)
                }
            }
            .padding(.horizontal, Theme.Spacing.s)
            .padding(.bottom, Theme.Spacing.xl)
        }
    }
}

// MARK: - cell

private struct HistoryCell: View {
    let item: HistoryItem
    let service: HistoryServicing
    let namespace: Namespace.ID
    @State private var image: UIImage?

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                RoundedRectangle(cornerRadius: 14)
                    .fill(.ultraThinMaterial)
                ProgressView()
            }
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(3.0 / 4.0, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .matchedTransitionSource(id: item.id, in: namespace)
        .task {
            if image == nil {
                let isPremium = await MainActor.run { PurchaseService.shared.isPremium }
                if let data = try? await service.imageData(
                    for: item.id,
                    variant: .thumb,
                    isPremium: isPremium
                ), let ui = UIImage(data: data) {
                    image = ui
                }
            }
        }
    }
}

private struct SectionHeader: View {
    let title: String
    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.Colors.textPrimary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .glassEffect(.clear, in: .capsule)
            Spacer()
        }
        .padding(.vertical, Theme.Spacing.s)
    }
}

/// Used when no `HistoryService` can be configured (e.g. xcconfig missing). The
/// History tab still renders but stays empty so the app builds and demos.
struct DisabledHistoryService: HistoryServicing {
    func save(imageJPEG: Data, thumbnailJPEG: Data, metadata: HistoryMetadata, isPremium: Bool) async throws -> HistoryItem {
        throw HistoryServiceError.missingWorkerURL
    }
    func list(isPremium: Bool) async throws -> HistoryListResponse {
        HistoryListResponse(items: [], totalCount: 0, freeLimitReached: false)
    }
    func imageData(for id: String, variant: HistoryImageVariant, isPremium: Bool) async throws -> Data {
        Data()
    }
    func delete(id: String, isPremium: Bool) async throws {}
}
