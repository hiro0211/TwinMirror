import Foundation
import UIKit

struct ImagePreprocessor {
    let targetSize: CGFloat
    let facePaddingRatio: CGFloat

    init(targetSize: CGFloat = 1024, facePaddingRatio: CGFloat = 0.6) {
        self.targetSize = targetSize
        self.facePaddingRatio = facePaddingRatio
    }

    /// Crops the image around the face bounding box to a square,
    /// expanding the crop window so the face occupies ~60% of the result,
    /// then resizes to `targetSize × targetSize`.
    func cropAndResize(image: UIImage, face: DetectedFace) -> UIImage? {
        guard let cgImage = image.cgImage else { return nil }
        let normalizedRect = visionToImageCoordinates(face.boundingBox, in: face.imageSize)
        let squareRect = expandToSquare(normalizedRect, in: face.imageSize, paddingRatio: facePaddingRatio)

        guard let cropped = cgImage.cropping(to: squareRect) else { return nil }
        let croppedImage = UIImage(cgImage: cropped, scale: image.scale, orientation: .up)

        return resize(image: croppedImage, to: CGSize(width: targetSize, height: targetSize))
    }

    /// Convert Vision normalized rect (origin bottom-left, 0..1) to image pixel rect (origin top-left).
    func visionToImageCoordinates(_ rect: CGRect, in size: CGSize) -> CGRect {
        let x = rect.origin.x * size.width
        let y = (1.0 - rect.origin.y - rect.height) * size.height
        let width = rect.width * size.width
        let height = rect.height * size.height
        return CGRect(x: x, y: y, width: width, height: height)
    }

    /// Expand a face rect to a square that contains the face occupying ~paddingRatio of the side.
    func expandToSquare(_ faceRect: CGRect, in imageSize: CGSize, paddingRatio: CGFloat) -> CGRect {
        let faceMaxSide = max(faceRect.width, faceRect.height)
        let desiredSide = faceMaxSide / paddingRatio

        let centerX = faceRect.midX
        let centerY = faceRect.midY

        var originX = centerX - desiredSide / 2
        var originY = centerY - desiredSide / 2
        var side = desiredSide

        // Clamp to image bounds while keeping it square.
        if originX < 0 { originX = 0 }
        if originY < 0 { originY = 0 }
        if originX + side > imageSize.width { side = imageSize.width - originX }
        if originY + side > imageSize.height { side = imageSize.height - originY }
        // If clamping made it non-square, take the smaller side.
        side = min(side, min(imageSize.width - originX, imageSize.height - originY))

        return CGRect(x: originX, y: originY, width: side, height: side)
    }

    func resize(image: UIImage, to size: CGSize) -> UIImage {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }

    /// Convenience: load image, detect face, crop & resize, return JPEG data ready for API.
    func process(image: UIImage, face: DetectedFace, jpegQuality: CGFloat = 0.85) -> Data? {
        guard let processed = cropAndResize(image: image, face: face) else { return nil }
        return processed.jpegData(compressionQuality: jpegQuality)
    }
}
