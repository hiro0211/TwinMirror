import XCTest
import UIKit
@testable import TwinMirror

@MainActor
final class WatermarkRendererTests: XCTestCase {

    private let imageWidth: Int = 864
    private let imageHeight: Int = 1152

    // MARK: - 仕様: サイズ・スケールが保持される

    func test_apply_preservesImageSize() {
        let renderer = TwinMirrorWatermark()
        let source = makeSolidImage(width: imageWidth, height: imageHeight, color: .white)

        let watermarked = renderer.apply(to: source)

        XCTAssertEqual(
            watermarked.size, source.size,
            "ウォーターマーク後も画像サイズは変わらない（焼き込みは合成のみ）"
        )
    }

    func test_apply_preservesImageScale() {
        let renderer = TwinMirrorWatermark()
        let source = makeSolidImage(width: imageWidth, height: imageHeight, color: .white, scale: 2)

        let watermarked = renderer.apply(to: source)

        XCTAssertEqual(
            watermarked.scale, source.scale,
            "デバイススケールが維持されないとピクセル解像度が劣化する"
        )
    }

    // MARK: - 仕様: 左下にウォーターマークが入る（中央は無傷）

    func test_apply_darkensBottomLeftRegion() {
        let renderer = TwinMirrorWatermark()
        let source = makeSolidImage(width: imageWidth, height: imageHeight, color: .white)

        let watermarked = renderer.apply(to: source)

        // 左下 1/4 領域（マージン込み）。半透明黒ピル + 白テキストで明度が下がる。
        let bottomLeftRect = CGRect(
            x: 0,
            y: CGFloat(imageHeight) * 0.85,
            width: CGFloat(imageWidth) * 0.5,
            height: CGFloat(imageHeight) * 0.15
        )
        let sourceBrightness = source.averageBrightness(in: bottomLeftRect) ?? -1
        let watermarkedBrightness = watermarked.averageBrightness(in: bottomLeftRect) ?? -1

        XCTAssertEqual(sourceBrightness, 255, accuracy: 2, "元画像は白なので 255 付近")
        XCTAssertLessThan(
            watermarkedBrightness, 240,
            "左下に半透明黒ピル + テキストが描かれるので明度が下がるはず"
        )
    }

    func test_apply_doesNotModifyCenter() {
        let renderer = TwinMirrorWatermark()
        let source = makeSolidImage(width: imageWidth, height: imageHeight, color: .white)

        let watermarked = renderer.apply(to: source)

        let centerRect = CGRect(
            x: CGFloat(imageWidth) * 0.4,
            y: CGFloat(imageHeight) * 0.4,
            width: CGFloat(imageWidth) * 0.2,
            height: CGFloat(imageHeight) * 0.2
        )
        let brightness = watermarked.averageBrightness(in: centerRect) ?? -1
        XCTAssertEqual(
            brightness, 255, accuracy: 2,
            "中央 20% 領域は watermark の対象外なので元の白のまま"
        )
    }

    func test_apply_doesNotModifyTopRight() {
        let renderer = TwinMirrorWatermark()
        let source = makeSolidImage(width: imageWidth, height: imageHeight, color: .white)

        let watermarked = renderer.apply(to: source)

        let topRightRect = CGRect(
            x: CGFloat(imageWidth) * 0.6,
            y: 0,
            width: CGFloat(imageWidth) * 0.4,
            height: CGFloat(imageHeight) * 0.4
        )
        let brightness = watermarked.averageBrightness(in: topRightRect) ?? -1
        XCTAssertEqual(brightness, 255, accuracy: 2, "右上は watermark 範囲外")
    }

    // MARK: - 仕様: 暗い背景でも視認性が保たれる（白文字が出る）

    func test_apply_onDarkBackground_keepsTextVisible() {
        let renderer = TwinMirrorWatermark()
        let source = makeSolidImage(width: imageWidth, height: imageHeight, color: .black)

        let watermarked = renderer.apply(to: source)

        let bottomLeftRect = CGRect(
            x: 0,
            y: CGFloat(imageHeight) * 0.85,
            width: CGFloat(imageWidth) * 0.5,
            height: CGFloat(imageHeight) * 0.15
        )
        let watermarkedBrightness = watermarked.averageBrightness(in: bottomLeftRect) ?? -1
        XCTAssertGreaterThan(
            watermarkedBrightness, 5,
            "黒地の上に白テキストが乗るので、わずかでも明度が上がるはず（完全黒のままなら何も描けていない）"
        )
    }
}

// MARK: - Helpers

private extension WatermarkRendererTests {
    func makeSolidImage(width: Int, height: Int, color: UIColor, scale: CGFloat = 1) -> UIImage {
        let size = CGSize(width: width, height: height)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = scale
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { ctx in
            ctx.cgContext.setFillColor(color.cgColor)
            ctx.cgContext.fill(CGRect(origin: .zero, size: size))
        }
    }
}

/// UIKit 座標系（top-left origin、point 単位）の rect で平均輝度（0-255）を取得する。
/// テストで「特定領域が変化したか」を検証するためのみのヘルパー。
private extension UIImage {
    func averageBrightness(in rect: CGRect) -> CGFloat? {
        guard let cgImage else { return nil }
        let pxW = cgImage.width
        let pxH = cgImage.height
        guard pxW > 0, pxH > 0 else { return nil }

        let bytesPerPixel = 4
        let bytesPerRow = pxW * bytesPerPixel
        var buffer = [UInt8](repeating: 0, count: pxW * pxH * bytesPerPixel)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
            | CGImageByteOrderInfo.order32Big.rawValue

        guard let context = CGContext(
            data: &buffer,
            width: pxW,
            height: pxH,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else { return nil }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: pxW, height: pxH))

        let rx = max(0, Int(rect.origin.x * scale))
        let ry = max(0, Int(rect.origin.y * scale))
        let rw = max(0, min(pxW - rx, Int(rect.size.width * scale)))
        let rh = max(0, min(pxH - ry, Int(rect.size.height * scale)))
        guard rw > 0, rh > 0 else { return nil }

        var sum = 0
        var count = 0
        for y in ry..<(ry + rh) {
            let rowBase = y * bytesPerRow
            for x in rx..<(rx + rw) {
                let i = rowBase + x * bytesPerPixel
                let r = Int(buffer[i])
                let g = Int(buffer[i + 1])
                let b = Int(buffer[i + 2])
                sum += (r + g + b) / 3
                count += 1
            }
        }
        return count > 0 ? CGFloat(sum) / CGFloat(count) : nil
    }
}
