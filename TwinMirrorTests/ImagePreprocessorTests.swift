import XCTest
@testable import TwinMirror

final class ImagePreprocessorTests: XCTestCase {
    private var preprocessor: ImagePreprocessor!

    override func setUp() {
        super.setUp()
        preprocessor = ImagePreprocessor(targetSize: 1024, facePaddingRatio: 0.6)
    }

    func test_visionToImageCoordinates_flipsY() {
        let visionRect = CGRect(x: 0.25, y: 0.25, width: 0.5, height: 0.5)
        let imageSize = CGSize(width: 1000, height: 1000)

        let imageRect = preprocessor.visionToImageCoordinates(visionRect, in: imageSize)

        XCTAssertEqual(imageRect.origin.x, 250, accuracy: 0.1)
        XCTAssertEqual(imageRect.origin.y, 250, accuracy: 0.1)
        XCTAssertEqual(imageRect.width, 500, accuracy: 0.1)
        XCTAssertEqual(imageRect.height, 500, accuracy: 0.1)
    }

    func test_visionToImageCoordinates_topLeftFace() {
        // Vision Y-up: a face at top-left has high y origin
        let visionRect = CGRect(x: 0.1, y: 0.7, width: 0.2, height: 0.2)
        let imageSize = CGSize(width: 1000, height: 1000)

        let imageRect = preprocessor.visionToImageCoordinates(visionRect, in: imageSize)

        XCTAssertEqual(imageRect.origin.x, 100, accuracy: 0.1)
        XCTAssertEqual(imageRect.origin.y, 100, accuracy: 0.1, "Top-left face should have low Y in image coords")
    }

    func test_expandToSquare_centersOnFace() {
        let faceRect = CGRect(x: 400, y: 400, width: 200, height: 200)
        let imageSize = CGSize(width: 1000, height: 1000)

        let square = preprocessor.expandToSquare(faceRect, in: imageSize, paddingRatio: 0.5)

        // Face is 200, padding ratio 0.5 → desired side 400
        XCTAssertEqual(square.width, 400, accuracy: 1.0)
        XCTAssertEqual(square.height, 400, accuracy: 1.0)
        XCTAssertEqual(square.midX, faceRect.midX, accuracy: 1.0)
        XCTAssertEqual(square.midY, faceRect.midY, accuracy: 1.0)
    }

    func test_expandToSquare_clampsToImageBounds() {
        // Face near edge — square should clamp to image without going negative
        let faceRect = CGRect(x: 50, y: 50, width: 100, height: 100)
        let imageSize = CGSize(width: 1000, height: 1000)

        let square = preprocessor.expandToSquare(faceRect, in: imageSize, paddingRatio: 0.3)

        XCTAssertGreaterThanOrEqual(square.origin.x, 0)
        XCTAssertGreaterThanOrEqual(square.origin.y, 0)
        XCTAssertLessThanOrEqual(square.origin.x + square.width, imageSize.width + 0.1)
        XCTAssertLessThanOrEqual(square.origin.y + square.height, imageSize.height + 0.1)
        XCTAssertEqual(square.width, square.height, accuracy: 0.1, "Result must remain square")
    }

    func test_resize_producesTargetSize() {
        let original = makeSolidImage(size: CGSize(width: 512, height: 768), color: .red)
        let resized = preprocessor.resize(image: original, to: CGSize(width: 1024, height: 1024))

        XCTAssertEqual(resized.size.width, 1024, accuracy: 0.5)
        XCTAssertEqual(resized.size.height, 1024, accuracy: 0.5)
    }

    func test_cropAndResize_producesValidJPEG() throws {
        let original = makeSolidImage(size: CGSize(width: 1000, height: 1000), color: .blue)
        // Synthetic face at center
        let face = DetectedFace(
            boundingBox: CGRect(x: 0.3, y: 0.3, width: 0.4, height: 0.4),
            imageSize: CGSize(width: 1000, height: 1000)
        )

        let data = preprocessor.process(image: original, face: face)

        XCTAssertNotNil(data)
        XCTAssertGreaterThan(data?.count ?? 0, 100, "JPEG should have meaningful payload")
    }

    private func makeSolidImage(size: CGSize, color: UIColor) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            color.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
        }
    }
}
