import Foundation
import UIKit
import Vision
import ImageIO

enum EyeCropper {
    struct CropResult {
        let image: UIImage
        let croppedRect: CGRect
    }

    static func cropPreferredEye(from imageData: Data, side: EyeSide) async -> Data? {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let result = cropPreferredEyeSync(from: imageData, side: side)
                continuation.resume(returning: result)
            }
        }
    }

    private static func cropPreferredEyeSync(from imageData: Data, side: EyeSide) -> Data? {
        guard let uiImage = UIImage(data: imageData) else { return nil }
        guard let cgImage = uiImage.cgImage else { return nil }

        let orientation = CGImagePropertyOrientation(uiImage.imageOrientation)

        let request = VNDetectFaceLandmarksRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return nil
        }

        guard let observation = request.results?.first as? VNFaceObservation else { return nil }
        guard let landmarks = observation.landmarks else { return nil }

        let region: VNFaceLandmarkRegion2D?
        switch side {
        case .left: region = landmarks.leftEye
        case .right: region = landmarks.rightEye
        }
        guard let eye = region, eye.pointCount > 0 else { return nil }

        // Visionの座標（顔のバウンディングボックスに対する正規化）→ 画像ピクセル座標に変換
        // 1) 目の点群のバウンディングボックス（正規化: faceBox内）
        var minX: CGFloat = 1
        var minY: CGFloat = 1
        var maxX: CGFloat = 0
        var maxY: CGFloat = 0
        for i in 0..<eye.pointCount {
            let p = eye.normalizedPoints[i]
            minX = min(minX, p.x)
            minY = min(minY, p.y)
            maxX = max(maxX, p.x)
            maxY = max(maxY, p.y)
        }

        let faceBox = observation.boundingBox // 画像全体に対する正規化座標（左下原点）
        let eyeBoxInFace = CGRect(
            x: minX,
            y: minY,
            width: max(0.0001, maxX - minX),
            height: max(0.0001, maxY - minY)
        )

        // 2) faceBox内の正規化座標 → 画像全体の正規化座標
        let eyeBox = CGRect(
            x: faceBox.origin.x + eyeBoxInFace.origin.x * faceBox.size.width,
            y: faceBox.origin.y + eyeBoxInFace.origin.y * faceBox.size.height,
            width: eyeBoxInFace.size.width * faceBox.size.width,
            height: eyeBoxInFace.size.height * faceBox.size.height
        )

        // 3) 正規化（左下原点）→ ピクセル（左上原点）に変換
        let imageW = CGFloat(cgImage.width)
        let imageH = CGFloat(cgImage.height)

        var rect = CGRect(
            x: eyeBox.origin.x * imageW,
            y: (1 - eyeBox.origin.y - eyeBox.size.height) * imageH,
            width: eyeBox.size.width * imageW,
            height: eyeBox.size.height * imageH
        )

        // 目の周りを少し広げる（まつ毛や虹彩周辺まで見えるように）
        let expandX = rect.width * 0.55
        let expandY = rect.height * 0.85
        rect = rect.insetBy(dx: -expandX, dy: -expandY)
        rect = rect.intersection(CGRect(x: 0, y: 0, width: imageW, height: imageH))

        guard rect.width > 10, rect.height > 10 else { return nil }

        guard let croppedCG = cgImage.cropping(to: rect) else { return nil }

        let cropped = UIImage(cgImage: croppedCG, scale: uiImage.scale, orientation: .up)
        return cropped.jpegData(compressionQuality: 0.92)
    }
}

private extension CGImagePropertyOrientation {
    init(_ uiOrientation: UIImage.Orientation) {
        switch uiOrientation {
        case .up: self = .up
        case .down: self = .down
        case .left: self = .left
        case .right: self = .right
        case .upMirrored: self = .upMirrored
        case .downMirrored: self = .downMirrored
        case .leftMirrored: self = .leftMirrored
        case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
    }
}

