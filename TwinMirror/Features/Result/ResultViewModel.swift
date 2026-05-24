import Foundation
import UIKit
import SwiftUI

@MainActor
@Observable
final class ResultViewModel {
    enum Phase {
        case loading
        case done(GenerationResult)
        case failed(String)
    }

    var phase: Phase = .loading
    var savedToast: String?
    var gender: ChildGender

    let fatherImage: UIImage
    let motherImage: UIImage
    private var request: GenerationRequest
    private let orchestrator: any GenerationOrchestrating
    private let saveService: PhotoSaving
    private let analytics: AnalyticsTracking
    private let reviewService: ReviewRequestService
    private let historyService: HistoryServicing?
    private let watermarker: Watermarking
    private let isPremiumProvider: @MainActor () -> Bool

    init(
        initialRequest: GenerationRequest,
        fatherImage: UIImage,
        motherImage: UIImage,
        saveService: PhotoSaving = PhotoSaveService(),
        analytics: AnalyticsTracking = DefaultAnalytics.shared,
        reviewService: ReviewRequestService = .shared,
        historyService: HistoryServicing? = HistoryService.makeDefault(),
        orchestrator: (any GenerationOrchestrating)? = nil,
        watermarker: Watermarking = TwinMirrorWatermark(),
        isPremiumProvider: @escaping @MainActor () -> Bool = { PurchaseService.shared.isPremium }
    ) {
        self.request = initialRequest
        self.gender = initialRequest.gender
        self.fatherImage = fatherImage
        self.motherImage = motherImage
        if let orchestrator {
            self.orchestrator = orchestrator
        } else if let workerURL = AppConfig.workerURL {
            self.orchestrator = GenerationOrchestrator(
                workerURL: workerURL,
                authToken: AppConfig.workerAuthToken
            )
        } else {
            self.orchestrator = GenerationOrchestrator(attempts: [])
        }
        self.saveService = saveService
        self.analytics = analytics
        self.reviewService = reviewService
        self.historyService = historyService
        self.watermarker = watermarker
        self.isPremiumProvider = isPremiumProvider
    }

    func generate() async {
        phase = .loading
        let mode = request.mode.rawValue
        let startedAt = Date()
        analytics.track(.generationStarted(mode: mode))
        do {
            let raw = try await orchestrator.generate(request: request)
            let result = isPremiumProvider() ? raw : applyWatermark(to: raw)
            phase = .done(result)
            let elapsedMs = Int(Date().timeIntervalSince(startedAt) * 1000)
            analytics.track(.generationSucceeded(mode: mode, elapsedMs: elapsedMs, imageCount: result.images.count))
            persistHistory(result: result)
        } catch {
            phase = .failed(error.localizedDescription)
            analytics.track(.generationFailed(mode: mode, errorKind: String(describing: type(of: error))))
        }
    }

    func regenerate(with newGender: ChildGender) async {
        gender = newGender
        request = GenerationRequest(
            fatherImageData: request.fatherImageData,
            motherImageData: request.motherImageData,
            gender: newGender,
            age: request.age,
            mode: request.mode
        )
        analytics.track(.resultRegenerated(newGender: newGender.rawValue))
        await generate()
    }

    @discardableResult
    func persistHistory(result: GenerationResult) -> Task<Void, Never>? {
        guard let historyService else { return nil }
        let isPremium = PurchaseService.shared.isPremium
        let styleString = result.usedStyle == .photorealistic ? "photorealistic" : "illustration"

        // best を先頭に並べ替え → server 側 createdAt がミリ秒精度なので、
        // 先に dispatch されたものが最古 = 履歴一覧 (DESC ソート) の先頭に出る。
        let orderedIndices: [Int] = {
            var indices = Array(result.images.indices)
            if let pos = indices.firstIndex(of: result.bestIndex) {
                indices.remove(at: pos)
                indices.insert(result.bestIndex, at: 0)
            }
            return indices
        }()

        struct PreparedUpload: Sendable {
            let imageJPEG: Data
            let thumb: Data
            let metadata: HistoryMetadata
        }

        let prepared: [PreparedUpload] = orderedIndices.compactMap { i in
            let image = result.images[i]
            guard let imageJPEG = image.jpegData(compressionQuality: 0.9), !imageJPEG.isEmpty else { return nil }
            let thumb = Self.thumbnailJPEG(from: image, maxDimension: 512)
            guard !thumb.isEmpty else { return nil }
            let ratio = result.ratios.indices.contains(i) ? result.ratios[i] : nil
            let metadata = HistoryMetadata(
                gender: request.gender.rawValue,
                age: String(request.age.years),
                mode: request.mode.rawValue,
                style: styleString,
                ratio: ratio?.rawValue,
                prompt: nil
            )
            return PreparedUpload(imageJPEG: imageJPEG, thumb: thumb, metadata: metadata)
        }

        guard !prepared.isEmpty else { return nil }

        return Task.detached(priority: .utility) { [historyService, prepared, analytics] in
            await withTaskGroup(of: Void.self) { group in
                for upload in prepared {
                    group.addTask {
                        do {
                            _ = try await historyService.save(
                                imageJPEG: upload.imageJPEG,
                                thumbnailJPEG: upload.thumb,
                                metadata: upload.metadata,
                                isPremium: isPremium
                            )
                        } catch {
                            analytics.track(.resultSaveFailed(errorKind: "history_\(type(of: error))"))
                        }
                    }
                }
            }
        }
    }

    /// 無料ユーザー向けの watermark 焼き込み。全画像経路（表示・保存・履歴）で
    /// 同じインスタンスを使うため、この `GenerationResult` を以降そのまま使えば一貫する。
    private func applyWatermark(to result: GenerationResult) -> GenerationResult {
        GenerationResult(
            images: result.images.map { watermarker.apply(to: $0) },
            bestIndex: result.bestIndex,
            usedStyle: result.usedStyle,
            ratios: result.ratios
        )
    }

    private static func thumbnailJPEG(from image: UIImage, maxDimension: CGFloat) -> Data {
        let size = image.size
        guard size.width > 0, size.height > 0 else { return Data() }
        let scale = min(1.0, maxDimension / max(size.width, size.height))
        let target = CGSize(width: size.width * scale, height: size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: target, format: format)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
        return resized.jpegData(compressionQuality: 0.7) ?? Data()
    }

    func saveCurrent(at index: Int) async {
        guard case .done(let result) = phase else { return }
        guard result.images.indices.contains(index) else { return }
        do {
            try await saveService.save(result.images[index])
            savedToast = "保存しました"
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            analytics.track(.resultSaved(index: index))
            reviewService.recordPositiveEvent()
            Task {
                try? await Task.sleep(nanoseconds: 2_500_000_000)
                await MainActor.run { savedToast = nil }
            }
        } catch {
            savedToast = error.localizedDescription
            analytics.track(.resultSaveFailed(errorKind: String(describing: type(of: error))))
        }
    }
}
