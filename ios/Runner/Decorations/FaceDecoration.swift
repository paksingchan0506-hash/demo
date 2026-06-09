import Foundation
import CoreGraphics
import MediaPipeTasksVision

protocol FaceDecoration {
    func draw(in context: CGContext, landmarks: [NormalizedLandmark], width: Int, height: Int)
}
