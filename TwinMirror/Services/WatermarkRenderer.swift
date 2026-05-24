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
