import SwiftUI
import UIKit

protocol Watermarking: Sendable {
    func apply(to image: UIImage) -> UIImage
}

/// TikTok / SNOW スタイルの左下ブランド表記。半透明ピル背景 + 白テキストで
/// 明暗どちらの背景でも視認性を確保。`PurchaseService.isPremium == false` の
/// ユーザーが生成した画像にのみ焼き込む前提（`ResultViewModel.generate()` で判定）。
struct TwinMirrorWatermark: Watermarking {
    var text: String = "TwinMirror"
    var marginRatio: CGFloat = 0.06       // 画像幅に対する端からの余白
    var fontSizeRatio: CGFloat = 0.045    // 画像幅に対するフォントサイズ
    var pillOpacity: CGFloat = 0.35
    var horizontalPaddingRatio: CGFloat = 0.022
    var verticalPaddingRatio: CGFloat = 0.012

    func apply(to image: UIImage) -> UIImage {
        let size = image.size
        guard size.width > 0, size.height > 0 else { return image }

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = image.scale

        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { _ in
            image.draw(at: .zero)
            drawWatermark(in: size)
        }
    }

    private func drawWatermark(in canvas: CGSize) {
        let fontSize = canvas.width * fontSizeRatio
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: fontSize, weight: .semibold),
            .foregroundColor: UIColor.white,
            .kern: fontSize * 0.02,
        ]
        let attributed = NSAttributedString(string: text, attributes: attributes)
        let textSize = attributed.size()

        let hPad = canvas.width * horizontalPaddingRatio
        let vPad = canvas.width * verticalPaddingRatio
        let pillSize = CGSize(
            width: ceil(textSize.width) + hPad * 2,
            height: ceil(textSize.height) + vPad * 2
        )
        let margin = canvas.width * marginRatio
        let pillRect = CGRect(
            x: margin,
            y: canvas.height - margin - pillSize.height,
            width: pillSize.width,
            height: pillSize.height
        )

        UIColor.black.withAlphaComponent(pillOpacity).setFill()
        UIBezierPath(roundedRect: pillRect, cornerRadius: pillSize.height / 2).fill()

        let textOrigin = CGPoint(
            x: pillRect.minX + hPad,
            y: pillRect.minY + (pillSize.height - textSize.height) / 2
        )
        attributed.draw(at: textOrigin)
    }
}

// MARK: - 表示時オーバーレイ（SwiftUI）

/// `TwinMirrorWatermark` と同じ見た目（左下・半透明ピル・白テキスト）を
/// SwiftUI の overlay として描画する。R2 にはクリーン画像を保存し、
/// 表示時にのみ無料ユーザー向けに重ねる用途。プレミアム化で
/// `PurchaseService.isPremium` が true になると `View` 拡張側で外れる。
struct WatermarkOverlay: View {
    var text: String = "TwinMirror"
    var marginRatio: CGFloat = 0.06
    var fontSizeRatio: CGFloat = 0.045
    var pillOpacity: CGFloat = 0.35
    var horizontalPaddingRatio: CGFloat = 0.022
    var verticalPaddingRatio: CGFloat = 0.012

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let fontSize = w * fontSizeRatio
            let hPad = w * horizontalPaddingRatio
            let vPad = w * verticalPaddingRatio
            let margin = w * marginRatio

            Text(text)
                .font(.system(size: fontSize, weight: .semibold))
                .kerning(fontSize * 0.02)
                .foregroundStyle(.white)
                .padding(.horizontal, hPad)
                .padding(.vertical, vPad)
                .background(Color.black.opacity(pillOpacity), in: .capsule)
                .padding(margin)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                .allowsHitTesting(false)
        }
        .allowsHitTesting(false)
    }
}

extension View {
    /// 無料ユーザーのとき右下に `WatermarkOverlay` を重ねる。プレミアム時は
    /// overlay 自体が付与されない（= ヒエラルキーも軽い）。
    /// 呼び出し側は `PurchaseService.shared.isPremium` を `@State` で購読し、
    /// 変化に応じてこの modifier が再評価されることを期待する。
    @ViewBuilder
    func watermarkedIfNeeded(isPremium: Bool) -> some View {
        if isPremium {
            self
        } else {
            self.overlay(WatermarkOverlay())
        }
    }
}
