import Foundation
import UIKit
import Vision
import ImageIO

enum EyeCropper {
    struct CropResult {
        let image: UIImage
        let croppedRect: CGRect
    }

    private struct EyeDetectionCandidate {
        let rect: CGRect
        let area: CGFloat
    }

    static func detectMostProminentEyeRect(from imageData: Data) async -> CGRect? {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let result = detectMostProminentEyeRectSync(from: imageData)
                continuation.resume(returning: result)
            }
        }
    }

    static func cropPreferredEye(from imageData: Data, side: EyeSide) async -> Data? {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let result = cropPreferredEyeSync(from: imageData, side: side)
                continuation.resume(returning: result)
            }
        }
    }

    private static func detectMostProminentEyeRectSync(from imageData: Data) -> CGRect? {
        guard let uiImage = UIImage(data: imageData),
              let cgImage = uiImage.cgImage else { return nil }

        let orientation = CGImagePropertyOrientation(uiImage.imageOrientation)
        guard let landmarks = detectLandmarks(in: cgImage, orientation: orientation) else { return nil }

        let candidates = EyeSide.allCases.compactMap { side -> EyeDetectionCandidate? in
            guard let rect = makeExpandedEyeRect(from: landmarks.observation, landmarks: landmarks.landmarks, side: side, imageSize: CGSize(width: cgImage.width, height: cgImage.height)) else {
                return nil
            }
            return EyeDetectionCandidate(rect: rect, area: rect.width * rect.height)
        }

        guard let best = candidates.max(by: { $0.area < $1.area }) else { return nil }
        return best.rect
    }

    private static func cropPreferredEyeSync(from imageData: Data, side: EyeSide) -> Data? {
        guard let uiImage = UIImage(data: imageData),
              let cgImage = uiImage.cgImage else { return nil }

        let orientation = CGImagePropertyOrientation(uiImage.imageOrientation)
        guard let landmarks = detectLandmarks(in: cgImage, orientation: orientation),
              let rect = makeExpandedEyeRect(
                from: landmarks.observation,
                landmarks: landmarks.landmarks,
                side: side,
                imageSize: CGSize(width: cgImage.width, height: cgImage.height)
              ) else { return nil }

        return crop(image: uiImage, cgImage: cgImage, to: rect)
    }

    private static func detectLandmarks(
        in cgImage: CGImage,
        orientation: CGImagePropertyOrientation
    ) -> (observation: VNFaceObservation, landmarks: VNFaceLandmarks2D)? {
        let request = VNDetectFaceLandmarksRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return nil
        }

        guard let observation = request.results?.first as? VNFaceObservation,
              let landmarks = observation.landmarks else {
            return nil
        }

        return (observation, landmarks)
    }

    private static func makeExpandedEyeRect(
        from observation: VNFaceObservation,
        landmarks: VNFaceLandmarks2D,
        side: EyeSide,
        imageSize: CGSize
    ) -> CGRect? {
        let region: VNFaceLandmarkRegion2D?
        switch side {
        case .left: region = landmarks.leftEye
        case .right: region = landmarks.rightEye
        }
        guard let eye = region, eye.pointCount > 0 else { return nil }

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

        let faceBox = observation.boundingBox
        let eyeBoxInFace = CGRect(
            x: minX,
            y: minY,
            width: max(0.0001, maxX - minX),
            height: max(0.0001, maxY - minY)
        )

        let eyeBox = CGRect(
            x: faceBox.origin.x + eyeBoxInFace.origin.x * faceBox.size.width,
            y: faceBox.origin.y + eyeBoxInFace.origin.y * faceBox.size.height,
            width: eyeBoxInFace.size.width * faceBox.size.width,
            height: eyeBoxInFace.size.height * faceBox.size.height
        )

        let imageW = imageSize.width
        let imageH = imageSize.height

        var rect = CGRect(
            x: eyeBox.origin.x * imageW,
            y: (1 - eyeBox.origin.y - eyeBox.size.height) * imageH,
            width: eyeBox.size.width * imageW,
            height: eyeBox.size.height * imageH
        )

        let expandX = rect.width * 0.55
        let expandY = rect.height * 0.85
        rect = rect.insetBy(dx: -expandX, dy: -expandY)
        rect = rect.intersection(CGRect(origin: .zero, size: imageSize))

        guard rect.width > 10, rect.height > 10 else { return nil }
        return rect
    }

    private static func crop(image: UIImage, cgImage: CGImage, to rect: CGRect) -> Data? {
        guard let croppedCG = cgImage.cropping(to: rect) else { return nil }
        let cropped = UIImage(cgImage: croppedCG, scale: image.scale, orientation: .up)
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
