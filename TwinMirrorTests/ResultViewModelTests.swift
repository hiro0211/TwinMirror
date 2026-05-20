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

@MainActor
final class ResultViewModelTests: XCTestCase {

    private func anyRequest(quality: GenerationQuality = .fast) -> GenerationRequest {
        GenerationRequest(
            fatherImageData: Data([0x01]),
            motherImageData: Data([0x02]),
            gender: .unspecified,
            age: ChildAge(years: 7),
            quality: quality
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
}
