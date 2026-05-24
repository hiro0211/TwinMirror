import XCTest
import UIKit
@testable import TwinMirror

private final class SpyPhotoSaver: PhotoSaving, @unchecked Sendable {
    var savedImages: [UIImage] = []
    var shouldThrow: Error?

    func save(_ image: UIImage) async throws {
        if let shouldThrow {
            throw shouldThrow
        }
        savedImages.append(image)
    }
}

private final class SpyWatermarker: Watermarking, @unchecked Sendable {
    var callCount = 0
    /// `apply` で返す画像。nil なら入力をそのまま返す（呼出回数のみ計測）。
    var stamped: UIImage?

    func apply(to image: UIImage) -> UIImage {
        callCount += 1
        return stamped ?? image
    }
}

private struct StubOrchestrator: GenerationOrchestrating {
    let result: GenerationResult
    func generate(request: GenerationRequest) async throws -> GenerationResult { result }
}

private actor SpyHistoryService: HistoryServicing {
    struct Call: Sendable {
        let imageJPEGSize: Int
        let metadata: HistoryMetadata
        let isPremium: Bool
    }

    var calls: [Call] = []
    /// Optional per-call failure: if non-empty, the i-th save call throws
    /// (consumed in order). Other calls succeed.
    var failureSequence: [Error?] = []

    func save(
        imageJPEG: Data,
        thumbnailJPEG: Data,
        metadata: HistoryMetadata,
        isPremium: Bool
    ) async throws -> HistoryItem {
        let index = calls.count
        calls.append(Call(imageJPEGSize: imageJPEG.count, metadata: metadata, isPremium: isPremium))
        if failureSequence.indices.contains(index), let err = failureSequence[index] {
            throw err
        }
        return HistoryItem(
            id: "spy-\(index)",
            createdAtMillis: Int64(Date().timeIntervalSince1970 * 1000),
            gender: metadata.gender,
            age: metadata.age,
            mode: metadata.mode,
            style: metadata.style,
            ratio: metadata.ratio,
            prompt: metadata.prompt
        )
    }

    func list(isPremium: Bool) async throws -> HistoryListResponse {
        HistoryListResponse(items: [], totalCount: 0, freeLimitReached: false)
    }

    func imageData(for id: String, variant: HistoryImageVariant, isPremium: Bool) async throws -> Data {
        Data()
    }

    func delete(id: String, isPremium: Bool) async throws {}

    func setFailureSequence(_ seq: [Error?]) { failureSequence = seq }
}

@MainActor
final class ResultViewModelTests: XCTestCase {

    private func anyRequest() -> GenerationRequest {
        GenerationRequest(
            fatherImageData: Data([0x01]),
            motherImageData: Data([0x02]),
            gender: .unspecified,
            age: ChildAge(years: 7)
        )
    }

    private func pixelImage(_ tag: Int) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 1, height: 1))
        let image = renderer.image { ctx in
            ctx.cgContext.setFillColor(UIColor(white: CGFloat(tag) / 10.0, alpha: 1).cgColor)
            ctx.cgContext.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
        }
        image.accessibilityIdentifier = "img-\(tag)"
        return image
    }

    private func makeViewModel(spy: SpyPhotoSaver) -> ResultViewModel {
        ResultViewModel(
            initialRequest: anyRequest(),
            fatherImage: pixelImage(0),
            motherImage: pixelImage(0),
            saveService: spy
        )
    }

    private func makeViewModel(
        history: HistoryServicing,
        request: GenerationRequest? = nil
    ) -> ResultViewModel {
        ResultViewModel(
            initialRequest: request ?? anyRequest(),
            fatherImage: pixelImage(0),
            motherImage: pixelImage(0),
            saveService: SpyPhotoSaver(),
            historyService: history
        )
    }

    private func premiumRequest() -> GenerationRequest {
        GenerationRequest(
            fatherImageData: Data([0x01]),
            motherImageData: Data([0x02]),
            gender: .female,
            age: ChildAge(years: 7),
            mode: .premium
        )
    }

    // MARK: - 高速モード（3枚）で正しい index の画像が保存される

    func test_saveCurrent_atFirstIndex_savesFirstImage() async {
        let spy = SpyPhotoSaver()
        let vm = makeViewModel(spy: spy)
        let images = [pixelImage(1), pixelImage(2), pixelImage(3)]
        vm.phase = .done(GenerationResult(images: images, bestIndex: 1, usedStyle: .photorealistic))

        await vm.saveCurrent(at: 0)

        XCTAssertEqual(spy.savedImages.count, 1, "保存は1回だけ呼ばれる")
        XCTAssertEqual(
            spy.savedImages.first?.accessibilityIdentifier,
            "img-1",
            "index=0 を指定したら images[0] が保存されなければならない（真ん中ではなく）"
        )
        XCTAssertEqual(vm.savedToast, "保存しました")
    }

    func test_saveCurrent_atLastIndex_savesLastImage() async {
        let spy = SpyPhotoSaver()
        let vm = makeViewModel(spy: spy)
        let images = [pixelImage(1), pixelImage(2), pixelImage(3)]
        vm.phase = .done(GenerationResult(images: images, bestIndex: 1, usedStyle: .photorealistic))

        await vm.saveCurrent(at: 2)

        XCTAssertEqual(
            spy.savedImages.first?.accessibilityIdentifier,
            "img-3",
            "index=2 を指定したら images[2] が保存されなければならない"
        )
    }

    func test_saveCurrent_atMiddleIndex_savesMiddleImage() async {
        let spy = SpyPhotoSaver()
        let vm = makeViewModel(spy: spy)
        let images = [pixelImage(1), pixelImage(2), pixelImage(3)]
        vm.phase = .done(GenerationResult(images: images, bestIndex: 1, usedStyle: .photorealistic))

        await vm.saveCurrent(at: 1)

        XCTAssertEqual(spy.savedImages.first?.accessibilityIdentifier, "img-2")
    }

    // MARK: - 範囲外 index は安全に無視

    func test_saveCurrent_outOfRangeIndex_doesNotCrashAndDoesNotSave() async {
        let spy = SpyPhotoSaver()
        let vm = makeViewModel(spy: spy)
        let images = [pixelImage(1), pixelImage(2), pixelImage(3)]
        vm.phase = .done(GenerationResult(images: images, bestIndex: 1, usedStyle: .photorealistic))

        await vm.saveCurrent(at: 99)
        await vm.saveCurrent(at: -1)

        XCTAssertTrue(spy.savedImages.isEmpty, "範囲外 index では save が呼ばれてはいけない")
        XCTAssertNil(vm.savedToast, "範囲外なら成功トーストも出ない")
    }

    // MARK: - loading フェーズでは何もしない

    func test_saveCurrent_whileLoading_doesNothing() async {
        let spy = SpyPhotoSaver()
        let vm = makeViewModel(spy: spy)
        // phase は init 直後 .loading のまま

        await vm.saveCurrent(at: 0)

        XCTAssertTrue(spy.savedImages.isEmpty)
    }

    // MARK: - 保存失敗時はエラーメッセージがトーストにセットされる

    func test_saveCurrent_whenSaveFails_setsErrorToast() async {
        let spy = SpyPhotoSaver()
        spy.shouldThrow = PhotoSaveError.unauthorized
        let vm = makeViewModel(spy: spy)
        let images = [pixelImage(1), pixelImage(2), pixelImage(3)]
        vm.phase = .done(GenerationResult(images: images, bestIndex: 1, usedStyle: .photorealistic))

        await vm.saveCurrent(at: 0)

        XCTAssertNotNil(vm.savedToast)
        XCTAssertNotEqual(vm.savedToast, "保存しました")
    }

    // MARK: - persistHistory: Premium モードは 3 枚すべて保存される

    func test_persistHistory_premium_savesAllThreeImages() async {
        let history = SpyHistoryService()
        let vm = makeViewModel(history: history, request: premiumRequest())
        let result = GenerationResult(
            images: [pixelImage(1), pixelImage(2), pixelImage(3)],
            bestIndex: 0,
            usedStyle: .photorealistic,
            ratios: [.balanced, .fatherLeaning, .motherLeaning]
        )

        await vm.persistHistory(result: result)?.value

        let calls = await history.calls
        XCTAssertEqual(calls.count, 3, "Premium モードは 3 枚すべて履歴に保存されなければならない")
    }

    func test_persistHistory_premium_eachSaveCarriesCorrectRatio() async {
        let history = SpyHistoryService()
        let vm = makeViewModel(history: history, request: premiumRequest())
        let result = GenerationResult(
            images: [pixelImage(1), pixelImage(2), pixelImage(3)],
            bestIndex: 0,
            usedStyle: .photorealistic,
            ratios: [.balanced, .fatherLeaning, .motherLeaning]
        )

        await vm.persistHistory(result: result)?.value

        let ratios = await history.calls.map { $0.metadata.ratio }
        XCTAssertEqual(Set(ratios).compactMap { $0 }.sorted(),
                       ["balanced", "fatherLeaning", "motherLeaning"].sorted(),
                       "各 save には対応する BlendRatio が記録される")
    }

    func test_persistHistory_premium_dispatchesBestFirst() async {
        let history = SpyHistoryService()
        let vm = makeViewModel(history: history, request: premiumRequest())
        let result = GenerationResult(
            images: [pixelImage(1), pixelImage(2), pixelImage(3)],
            bestIndex: 2,  // bestIndex=2 → "motherLeaning"
            usedStyle: .photorealistic,
            ratios: [.balanced, .fatherLeaning, .motherLeaning]
        )

        await vm.persistHistory(result: result)?.value

        let firstRatio = await history.calls.first?.metadata.ratio
        XCTAssertEqual(firstRatio, "motherLeaning",
                       "best (=bestIndex=2 → motherLeaning) が最初に dispatch されて履歴の最上位に出る")
    }

    func test_persistHistory_fast_savesSingleImage() async {
        let history = SpyHistoryService()
        let vm = makeViewModel(history: history)  // anyRequest = fast mode
        let result = GenerationResult(
            images: [pixelImage(1)],
            bestIndex: 0,
            usedStyle: .photorealistic,
            ratios: [.balanced]
        )

        await vm.persistHistory(result: result)?.value

        let calls = await history.calls
        XCTAssertEqual(calls.count, 1, "Fast モードは 1 枚のみ保存")
        XCTAssertEqual(calls.first?.metadata.ratio, "balanced")
    }

    // MARK: - 無料ユーザー: 生成画像に watermark が焼き込まれる

    func test_generate_appliesWatermarkToAllImages_whenFreeTier() async {
        let images = [pixelImage(1), pixelImage(2), pixelImage(3)]
        let stub = StubOrchestrator(result: GenerationResult(
            images: images,
            bestIndex: 0,
            usedStyle: .photorealistic,
            ratios: [.balanced, .fatherLeaning, .motherLeaning]
        ))
        let spy = SpyWatermarker()
        let stamped = pixelImage(9)
        spy.stamped = stamped

        let vm = ResultViewModel(
            initialRequest: premiumRequest(),  // 3 images の生成リクエスト形
            fatherImage: pixelImage(0),
            motherImage: pixelImage(0),
            saveService: SpyPhotoSaver(),
            historyService: nil,  // 履歴ロジックは別テストでカバー済
            orchestrator: stub,
            watermarker: spy,
            isPremiumProvider: { false }
        )

        await vm.generate()

        XCTAssertEqual(spy.callCount, 3, "無料ユーザーは生成された全画像に watermark が焼き込まれる")
        guard case .done(let result) = vm.phase else {
            return XCTFail("生成成功なら .done に遷移する")
        }
        XCTAssertEqual(
            result.images.map { $0.accessibilityIdentifier },
            ["img-9", "img-9", "img-9"],
            "ViewModel が保持する images は watermark 後のもの（= スパイが返した stamped 画像）"
        )
    }

    // MARK: - プレミアムユーザー: 焼き込み処理が呼ばれない

    func test_generate_skipsWatermark_whenPremium() async {
        let images = [pixelImage(1), pixelImage(2)]
        let stub = StubOrchestrator(result: GenerationResult(
            images: images,
            bestIndex: 0,
            usedStyle: .photorealistic,
            ratios: [.balanced, .fatherLeaning]
        ))
        let spy = SpyWatermarker()

        let vm = ResultViewModel(
            initialRequest: premiumRequest(),
            fatherImage: pixelImage(0),
            motherImage: pixelImage(0),
            saveService: SpyPhotoSaver(),
            historyService: nil,
            orchestrator: stub,
            watermarker: spy,
            isPremiumProvider: { true }
        )

        await vm.generate()

        XCTAssertEqual(spy.callCount, 0, "プレミアムユーザーには watermark を焼き込まない")
        guard case .done(let result) = vm.phase else {
            return XCTFail("生成成功なら .done に遷移する")
        }
        XCTAssertEqual(
            result.images.map { $0.accessibilityIdentifier },
            ["img-1", "img-2"],
            "プレミアム時は元画像がそのまま images に入る"
        )
    }

    // MARK: - watermark 適用後の画像がカメラロール保存にも流れる

    func test_saveCurrent_savesWatermarkedImage_whenFreeTier() async {
        let images = [pixelImage(1)]
        let stub = StubOrchestrator(result: GenerationResult(
            images: images,
            bestIndex: 0,
            usedStyle: .photorealistic,
            ratios: [.balanced]
        ))
        let spy = SpyWatermarker()
        spy.stamped = pixelImage(9)
        let saver = SpyPhotoSaver()

        let vm = ResultViewModel(
            initialRequest: anyRequest(),
            fatherImage: pixelImage(0),
            motherImage: pixelImage(0),
            saveService: saver,
            historyService: nil,
            orchestrator: stub,
            watermarker: spy,
            isPremiumProvider: { false }
        )

        await vm.generate()
        await vm.saveCurrent(at: 0)

        XCTAssertEqual(
            saver.savedImages.first?.accessibilityIdentifier, "img-9",
            "保存される画像は watermark 焼き込み後のもの（元画像 img-1 ではなく）"
        )
    }

    func test_persistHistory_perImageFailure_doesNotAbortOthers() async {
        let history = SpyHistoryService()
        await history.setFailureSequence([
            nil,
            HistoryServiceError.requestFailed(statusCode: 500, body: "down"),
            nil,
        ])
        let vm = makeViewModel(history: history, request: premiumRequest())
        let result = GenerationResult(
            images: [pixelImage(1), pixelImage(2), pixelImage(3)],
            bestIndex: 0,
            usedStyle: .photorealistic,
            ratios: [.balanced, .fatherLeaning, .motherLeaning]
        )

        await vm.persistHistory(result: result)?.value

        let calls = await history.calls
        XCTAssertEqual(calls.count, 3, "1 件失敗しても残り 2 件は試行され、失敗した 1 件も calls にカウントされる")
    }
}
