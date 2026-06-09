import Foundation
import AVFoundation
import UIKit
import MediaPipeTasksVision

protocol MaskDrawer2D {
    func draw(on pixelBuffer: CVPixelBuffer, landmarks: [NormalizedLandmark]) -> CVPixelBuffer
}

class MaskDrawer: MaskDrawer2D {
    func draw(on pixelBuffer: CVPixelBuffer, landmarks: [NormalizedLandmark]) -> CVPixelBuffer {
        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(data: baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: bytesPerRow, space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue) else {
            return pixelBuffer
        }
        if landmarks.count > 454 {
            context.setLineWidth(2.0)
            context.setStrokeColor(UIColor.systemBlue.cgColor)
            context.setFillColor(UIColor.systemBlue.withAlphaComponent(0.5).cgColor)
            let maskIndices = [234, 93, 132, 58, 172, 136, 152, 365, 397, 288, 323, 454, 356, 195, 127]
            let firstPoint = landmarks[maskIndices[0]]
            context.beginPath()
            context.move(to: CGPoint(x: CGFloat(firstPoint.x) * CGFloat(width), y: CGFloat(firstPoint.y) * CGFloat(height)))
            for i in 1..<maskIndices.count {
                let p = landmarks[maskIndices[i]]
                context.addLine(to: CGPoint(x: CGFloat(p.x) * CGFloat(width), y: CGFloat(p.y) * CGFloat(height)))
            }
            context.closePath()
            context.drawPath(using: .fillStroke)
        }
        return pixelBuffer
    }
}

class FullFaceDrawer: MaskDrawer2D {
    func draw(on pixelBuffer: CVPixelBuffer, landmarks: [NormalizedLandmark]) -> CVPixelBuffer {
        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(data: baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: bytesPerRow, space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue) else {
            return pixelBuffer
        }
        if landmarks.count > 454 {
            context.setLineWidth(2.0)
            context.setStrokeColor(UIColor.purple.cgColor)
            context.setFillColor(UIColor.purple.withAlphaComponent(0.35).cgColor)
            let indices = [10, 152, 234, 454]
            let pts = indices.compactMap { i -> CGPoint? in
                if i < landmarks.count {
                    return CGPoint(x: CGFloat(landmarks[i].x) * CGFloat(width), y: CGFloat(landmarks[i].y) * CGFloat(height))
                }
                return nil
            }
            if pts.count == 4 {
                let minX = pts.map { $0.x }.min() ?? 0
                let maxX = pts.map { $0.x }.max() ?? CGFloat(width)
                let minY = pts.map { $0.y }.min() ?? 0
                let maxY = pts.map { $0.y }.max() ?? CGFloat(height)
                let rect = CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
                context.fillEllipse(in: rect)
                context.strokeEllipse(in: rect)
            }
        }
        return pixelBuffer
    }
}

class UpperFaceDrawer: MaskDrawer2D {
    func draw(on pixelBuffer: CVPixelBuffer, landmarks: [NormalizedLandmark]) -> CVPixelBuffer {
        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(data: baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: bytesPerRow, space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue) else {
            return pixelBuffer
        }
        if landmarks.count > 454 {
            context.setLineWidth(2.0)
            context.setStrokeColor(UIColor.systemTeal.cgColor)
            context.setFillColor(UIColor.systemTeal.withAlphaComponent(0.5).cgColor)
            let leftEye = landmarks[33]
            let rightEye = landmarks[263]
            let eyeY = (CGFloat(leftEye.y) + CGFloat(rightEye.y)) / 2.0 * CGFloat(height)
            let leftX = CGFloat(leftEye.x) * CGFloat(width)
            let rightX = CGFloat(rightEye.x) * CGFloat(width)
            let bandHeight: CGFloat = max(CGFloat(height) * 0.06, 12)
            let rect = CGRect(x: min(leftX, rightX) - 20, y: eyeY - bandHeight / 2, width: abs(rightX - leftX) + 40, height: bandHeight)
            let rrect = UIBezierPath(roundedRect: rect, cornerRadius: bandHeight / 2)
            context.addPath(rrect.cgPath)
            context.drawPath(using: .fillStroke)
        }
        return pixelBuffer
    }
}

enum MaskDrawerFactory {
    static func make(_ type: String) -> MaskDrawer2D {
        switch type {
        case "full_face": return FullFaceDrawer()
        case "upper_face": return UpperFaceDrawer()
        default: return MaskDrawer()
        }
    }
}
