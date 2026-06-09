import Foundation
import UIKit
import MediaPipeTasksVision
import Flutter

class UpperFaceDecoration: FaceDecoration {
    func draw(in context: CGContext, landmarks: [NormalizedLandmark], width: Int, height: Int) {
        let idx = [10, 338, 297, 332, 284, 251, 389, 356, 454, 168, 234, 127, 162, 21, 54, 103, 67, 109]
        guard !landmarks.isEmpty else { return }
        var minX = CGFloat.greatestFiniteMagnitude, maxX = CGFloat.leastNormalMagnitude
        var minY = CGFloat.greatestFiniteMagnitude, maxY = CGFloat.leastNormalMagnitude
        for i in idx where i < landmarks.count {
            let p = landmarks[i]
            let x = CGFloat(p.x) * CGFloat(width)
            let y = CGFloat(p.y) * CGFloat(height)
            if x < minX { minX = x }; if x > maxX { maxX = x }
            if y < minY { minY = y }; if y > maxY { maxY = y }
        }
        let cx = (minX + maxX) * 0.5
        let cy = (minY + maxY) * 0.5
        let w = (maxX - minX) * 1.76
        let h = (maxY - minY) * 1.76
        let down = h * 0.10
        let rect = CGRect(x: cx - w * 0.5, y: cy - h * 0.5 + down, width: w, height: h)
        if let img = loadImage(asset: "assets/masks/upper_face_logo.png") {
            UIGraphicsPushContext(context)
            img.draw(in: rect)
            UIGraphicsPopContext()
        }
    }
    
    private func loadImage(asset: String) -> UIImage? {
        let key = FlutterDartProject.lookupKey(forAsset: asset)
        if let path = Bundle.main.path(forResource: key, ofType: nil) {
            return UIImage(contentsOfFile: path)
        }
        return nil
    }
}
