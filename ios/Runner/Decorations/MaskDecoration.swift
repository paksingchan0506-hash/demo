import Foundation
import UIKit
import MediaPipeTasksVision
import Flutter

class MaskDecoration: FaceDecoration {
    func draw(in context: CGContext, landmarks: [NormalizedLandmark], width: Int, height: Int) {
        let indices = [234, 93, 132, 58, 172, 136, 152, 365, 397, 288, 323, 454, 356, 195, 127]
        guard landmarks.count > 454 else { return }
        var minX = CGFloat.greatestFiniteMagnitude, maxX = CGFloat.leastNormalMagnitude
        var minY = CGFloat.greatestFiniteMagnitude, maxY = CGFloat.leastNormalMagnitude
        for i in indices {
            let p = landmarks[i]
            let x = CGFloat(p.x) * CGFloat(width)
            let y = CGFloat(p.y) * CGFloat(height)
            if x < minX { minX = x }; if x > maxX { maxX = x }
            if y < minY { minY = y }; if y > maxY { maxY = y }
        }
        let maskW = maxX - minX
        let maskH = maxY - minY
        let padX = maskW * 0.10
        let padY = maskH * 0.05
        let rect = CGRect(x: minX - padX, y: minY - padY, width: maskW + 2*padX, height: maskH + 2*padY)
        if let img = loadImage(asset: "assets/masks/mask_logo.png") {
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
