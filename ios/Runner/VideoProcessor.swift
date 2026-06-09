import Foundation
import AVFoundation
import MediaPipeTasksVision
import UIKit
import Flutter
import TensorFlowLite

class VideoProcessor: NSObject {
    static let shared = VideoProcessor()
    
    protocol Drawer2D {
        func draw(on pixelBuffer: CVPixelBuffer, landmarks: [NormalizedLandmark]) -> CVPixelBuffer
    }
    
    class MaskDrawer: NSObject, Drawer2D {
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
    
    class FullFaceDrawer: NSObject, Drawer2D {
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
    
    class UpperFaceDrawer: NSObject, Drawer2D {
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
    
    class MaskDrawerFactory: NSObject {
        static func make(_ type: String) -> Drawer2D {
            switch type {
            case "full_face": return FullFaceDrawer()
            case "upper_face": return UpperFaceDrawer()
            default: return MaskDrawer()
            }
        }
    }
    
    private var faceLandmarker: FaceLandmarker?
    private var nsfwInterpreter: Interpreter?
    
    override init() {
        super.init()
    }
    
    func setupMediaPipe() -> Bool {
        let assetKey = FlutterDartProject.lookupKey(forAsset: "assets/mediapipe/face_landmarker.task")
        guard let modelPath = Bundle.main.path(forResource: assetKey, ofType: nil) else {
            print("Failed to load model from Flutter assets: assets/mediapipe/face_landmarker.task")
            return false
        }
        do {
            let baseOptions = BaseOptions(modelAssetPath: modelPath)
            let options = FaceLandmarkerOptions()
            options.baseOptions = baseOptions
            options.runningMode = .video
            options.numFaces = 1
            options.minFaceDetectionConfidence = 0.5
            options.minFacePresenceConfidence = 0.5
            options.minTrackingConfidence = 0.5
            
            faceLandmarker = try FaceLandmarker(options: options)
            return true
        } catch {
            print("Failed to create FaceLandmarker: \(error)")
            return false
        }
    }
    
    func processVideo(inputPath: String, result: @escaping FlutterResult) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            if self.faceLandmarker == nil {
                if !self.setupMediaPipe() {
                    DispatchQueue.main.async {
                        result(FlutterError(code: "INIT_ERROR", message: "Failed to initialize MediaPipe. Check if face_landmarker.task is in Bundle.", details: nil))
                    }
                    return
                }
            }
            
            let fileURL = URL(fileURLWithPath: inputPath)
            let asset = AVAsset(url: fileURL)
            
            let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let outputURL = documentsDirectory.appendingPathComponent("output_\(Int(Date().timeIntervalSince1970)).mp4")
            
            if FileManager.default.fileExists(atPath: outputURL.path) {
                try? FileManager.default.removeItem(at: outputURL)
            }
            
            self.processAsset(asset: asset, outputURL: outputURL) { success, errorMsg in
                DispatchQueue.main.async {
                    if success {
                        result(outputURL.path)
                    } else {
                        result(FlutterError(code: "PROCESS_ERROR", message: errorMsg, details: nil))
                    }
                }
            }
        }
    }
    
    func processVideo2D(inputPath: String, decorationType: String, result: @escaping FlutterResult) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            if self.faceLandmarker == nil {
                if !self.setupMediaPipe() {
                    DispatchQueue.main.async {
                        result(FlutterError(code: "INIT_ERROR", message: "Failed to initialize MediaPipe. Check if face_landmarker.task is in Bundle.", details: nil))
                    }
                    return
                }
            }
            
            let fileURL = URL(fileURLWithPath: inputPath)
            let asset = AVAsset(url: fileURL)
            
            let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let outputURL = documentsDirectory.appendingPathComponent("output2D_\(Int(Date().timeIntervalSince1970)).mp4")
            
            if FileManager.default.fileExists(atPath: outputURL.path) {
                try? FileManager.default.removeItem(at: outputURL)
            }
            
            self.processAsset2D(asset: asset, outputURL: outputURL, decorationType: decorationType) { success, errorMsg in
                DispatchQueue.main.async {
                    if success {
                        result(outputURL.path)
                    } else {
                        result(FlutterError(code: "PROCESS_ERROR", message: errorMsg, details: nil))
                    }
                }
            }
        }
    }
    
    private func processAsset2D(asset: AVAsset, outputURL: URL, decorationType: String, completion: @escaping (Bool, String?) -> Void) {
        guard let reader = try? AVAssetReader(asset: asset) else {
            completion(false, "Failed to create AVAssetReader")
            return
        }
        guard let videoTrack = asset.tracks(withMediaType: .video).first else {
            completion(false, "No video track found")
            return
        }
        let readerOutputSettings: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)
        ]
        let readerOutput = AVAssetReaderTrackOutput(track: videoTrack, outputSettings: readerOutputSettings)
        if reader.canAdd(readerOutput) { reader.add(readerOutput) } else {
            completion(false, "Cannot add reader output"); return
        }
        guard let writer = try? AVAssetWriter(outputURL: outputURL, fileType: .mp4) else {
            completion(false, "Failed to create AVAssetWriter"); return
        }
        let writerInputSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: videoTrack.naturalSize.width,
            AVVideoHeightKey: videoTrack.naturalSize.height
        ]
        let writerInput = AVAssetWriterInput(mediaType: .video, outputSettings: writerInputSettings)
        writerInput.expectsMediaDataInRealTime = false
        writerInput.transform = videoTrack.preferredTransform
        let sourcePixelBufferAttributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA),
            kCVPixelBufferWidthKey as String: videoTrack.naturalSize.width,
            kCVPixelBufferHeightKey as String: videoTrack.naturalSize.height
        ]
        let pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: writerInput, sourcePixelBufferAttributes: sourcePixelBufferAttributes)
        if writer.canAdd(writerInput) { writer.add(writerInput) } else {
            completion(false, "Cannot add writer input"); return
        }
        guard reader.startReading() else { completion(false, "Failed to start reading"); return }
        guard writer.startWriting() else { completion(false, "Failed to start writing"); return }
        writer.startSession(atSourceTime: .zero)

        let processingQueue = DispatchQueue(label: "videoProcessingQueue2D")
        let decoration = DecorationFactory.create(type: decorationType)

        writerInput.requestMediaDataWhenReady(on: processingQueue) {
            while writerInput.isReadyForMoreMediaData {
                guard let sampleBuffer = readerOutput.copyNextSampleBuffer() else {
                    writerInput.markAsFinished()
                    writer.finishWriting {
                        if writer.status == .completed {
                            self.mergeAudio(originalAsset: asset, processedUrl: outputURL) { ok, err in
                                if ok { completion(true, nil) }
                                else { completion(false, err ?? "Audio merge failed") }
                            }
                        } else {
                            completion(false, "Writer failed: \(writer.error?.localizedDescription ?? "Unknown")")
                        }
                    }
                    break
                }
                let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
                let timestampMs = Int(CMTimeGetSeconds(timestamp) * 1000)
                if let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
                    var finalBuffer: CVPixelBuffer = imageBuffer
                    do {
                        let mpImage = try MPImage(sampleBuffer: sampleBuffer, orientation: .up)
                        let result = try self.faceLandmarker?.detect(videoFrame: mpImage, timestampInMilliseconds: timestampMs)
                        if let result = result, !result.faceLandmarks.isEmpty {
                            finalBuffer = self.drawDecoration(on: imageBuffer, landmarks: result.faceLandmarks[0], decoration: decoration)
                        }
                    } catch {
                        print("Detection/Draw error: \(error)")
                    }
                    if !pixelBufferAdaptor.append(finalBuffer, withPresentationTime: timestamp) {
                        print("Failed to append buffer")
                    }
                }
            }
        }
    }
    
    private func drawDecoration(on pixelBuffer: CVPixelBuffer, landmarks: [NormalizedLandmark], decoration: FaceDecoration) -> CVPixelBuffer {
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
        decoration.draw(in: context, landmarks: landmarks, width: width, height: height)
        return pixelBuffer
    }
    private func processAsset(asset: AVAsset, outputURL: URL, completion: @escaping (Bool, String?) -> Void) {
        guard let reader = try? AVAssetReader(asset: asset) else {
            completion(false, "Failed to create AVAssetReader")
            return
        }
        
        guard let videoTrack = asset.tracks(withMediaType: .video).first else {
            completion(false, "No video track found")
            return
        }
        
        let readerOutputSettings: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)
        ]
        let readerOutput = AVAssetReaderTrackOutput(track: videoTrack, outputSettings: readerOutputSettings)
        if reader.canAdd(readerOutput) {
            reader.add(readerOutput)
        } else {
            completion(false, "Cannot add reader output")
            return
        }
        
        guard let writer = try? AVAssetWriter(outputURL: outputURL, fileType: .mp4) else {
            completion(false, "Failed to create AVAssetWriter")
            return
        }
        
        let writerInputSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: videoTrack.naturalSize.width,
            AVVideoHeightKey: videoTrack.naturalSize.height
        ]
        let writerInput = AVAssetWriterInput(mediaType: .video, outputSettings: writerInputSettings)
        writerInput.expectsMediaDataInRealTime = false
        writerInput.transform = videoTrack.preferredTransform
        
        let sourcePixelBufferAttributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA),
            kCVPixelBufferWidthKey as String: videoTrack.naturalSize.width,
            kCVPixelBufferHeightKey as String: videoTrack.naturalSize.height
        ]
        let pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: writerInput, sourcePixelBufferAttributes: sourcePixelBufferAttributes)
        
        if writer.canAdd(writerInput) {
            writer.add(writerInput)
        } else {
            completion(false, "Cannot add writer input")
            return
        }
        
        if !reader.startReading() {
            completion(false, "Failed to start reading")
            return
        }
        
        if !writer.startWriting() {
            completion(false, "Failed to start writing")
            return
        }
        
        writer.startSession(atSourceTime: .zero)
        
        let processingQueue = DispatchQueue(label: "videoProcessingQueue")
        
        writerInput.requestMediaDataWhenReady(on: processingQueue) {
            while writerInput.isReadyForMoreMediaData {
                if let sampleBuffer = readerOutput.copyNextSampleBuffer() {
                    let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
                    let timestampMs = Int(CMTimeGetSeconds(timestamp) * 1000)
                    
                    if let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
                        var finalBuffer = imageBuffer
                        
                        do {
                            let mpImage = try MPImage(sampleBuffer: sampleBuffer, orientation: .up)
                            let result = try self.faceLandmarker?.detect(videoFrame: mpImage, timestampInMilliseconds: timestampMs)
                            
                            if let result = result, !result.faceLandmarks.isEmpty {
                                finalBuffer = self.drawMask(on: imageBuffer, landmarks: result.faceLandmarks[0])
                            }
                        } catch {
                            print("Detection/Draw error: \(error)")
                        }
                        
                        if !pixelBufferAdaptor.append(finalBuffer, withPresentationTime: timestamp) {
                            print("Failed to append buffer")
                        }
                    }
                } else {
                    writerInput.markAsFinished()
                    writer.finishWriting {
                        if writer.status == .completed {
                            completion(true, nil)
                        } else {
                            completion(false, "Writer failed: \(writer.error?.localizedDescription ?? "Unknown")")
                        }
                    }
                    break
                }
            }
        }
    }
    
    private func drawMask(on pixelBuffer: CVPixelBuffer, landmarks: [NormalizedLandmark]) -> CVPixelBuffer {
        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }
        
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        
        guard let context = CGContext(data: baseAddress,
                                      width: width,
                                      height: height,
                                      bitsPerComponent: 8,
                                      bytesPerRow: bytesPerRow,
                                      space: colorSpace,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue) else {
            return pixelBuffer
        }
        
        let maskIndices = [234, 93, 132, 58, 172, 136, 152, 365, 397, 288, 323, 454, 356, 195, 127]
        
        if landmarks.count > 454 {
            context.beginPath()
            context.setLineWidth(2.0)
            context.setStrokeColor(UIColor.blue.cgColor)
            context.setFillColor(UIColor.blue.withAlphaComponent(0.5).cgColor)
            
            let firstPoint = landmarks[maskIndices[0]]
            context.move(to: CGPoint(x: CGFloat(firstPoint.x) * CGFloat(width), y: CGFloat(firstPoint.y) * CGFloat(height)))
            
            for i in 1..<maskIndices.count {
                let point = landmarks[maskIndices[i]]
                context.addLine(to: CGPoint(x: CGFloat(point.x) * CGFloat(width), y: CGFloat(point.y) * CGFloat(height)))
            }
            
            context.closePath()
            context.drawPath(using: .fillStroke)
        }
        
        return pixelBuffer
    }
    
    private func mergeAudio(originalAsset: AVAsset, processedUrl: URL, completion: @escaping (Bool, String?) -> Void) {
        let processedAsset = AVAsset(url: processedUrl)
        let mixComposition = AVMutableComposition()
        guard let videoTrack = processedAsset.tracks(withMediaType: .video).first else {
            completion(false, "Processed video track missing"); return
        }
        let duration = processedAsset.duration
        guard let compVideoTrack = mixComposition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            completion(false, "Failed to create composition video track"); return
        }
        do {
            try compVideoTrack.insertTimeRange(CMTimeRange(start: .zero, duration: duration), of: videoTrack, at: .zero)
            compVideoTrack.preferredTransform = videoTrack.preferredTransform
        } catch {
            completion(false, "Insert video failed: \(error.localizedDescription)"); return
        }
        if let audioTrack = originalAsset.tracks(withMediaType: .audio).first,
           let compAudioTrack = mixComposition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) {
            do {
                let audioDuration = min(duration, originalAsset.duration)
                try compAudioTrack.insertTimeRange(CMTimeRange(start: .zero, duration: audioDuration), of: audioTrack, at: .zero)
            } catch {
                // ignore audio insertion failure, keep video-only
            }
        }
        let outUrl = processedUrl.deletingLastPathComponent().appendingPathComponent("output2D_audio_\(Int(Date().timeIntervalSince1970)).mp4")
        if FileManager.default.fileExists(atPath: outUrl.path) { try? FileManager.default.removeItem(at: outUrl) }
        guard let exporter = AVAssetExportSession(asset: mixComposition, presetName: AVAssetExportPresetHighestQuality) else {
            completion(false, "Create exporter failed"); return
        }
        exporter.outputURL = outUrl
        exporter.outputFileType = .mp4
        exporter.shouldOptimizeForNetworkUse = true
        exporter.exportAsynchronously {
            switch exporter.status {
            case .completed:
                try? FileManager.default.removeItem(at: processedUrl)
                try? FileManager.default.moveItem(at: outUrl, to: processedUrl)
                completion(true, nil)
            case .failed, .cancelled:
                completion(false, exporter.error?.localizedDescription ?? "Export failed")
            default:
                completion(false, "Unknown export state")
            }
        }
    }
    
    private func setupNsfwInterpreter() -> Bool {
        if nsfwInterpreter != nil {
            return true
        }
        let assetKey = FlutterDartProject.lookupKey(forAsset: "assets/NSFW/nsfw.tflite")
        guard let path = Bundle.main.path(forResource: assetKey, ofType: nil) else {
            print("Failed to find nsfw.tflite in bundle")
            return false
        }
        do {
            var options = InterpreterOptions()
            options.threadCount = 2
            let interpreter = try Interpreter(modelPath: path, options: options)
            try interpreter.allocateTensors()
            nsfwInterpreter = interpreter
            return true
        } catch {
            print("Failed to create NSFW interpreter: \(error)")
            return false
        }
    }
    
    private func classifyFrame(_ image: UIImage) -> Float {
        guard let interpreter = nsfwInterpreter else {
            return 0
        }
        guard let resized = resizeImage(image: image, size: CGSize(width: 256, height: 256)),
              let jpegData = resized.jpegData(compressionQuality: 0.95),
              let decoded = UIImage(data: jpegData),
              let cropped = centerCrop(image: decoded, size: CGSize(width: 224, height: 224)),
              let cgImage = cropped.cgImage else {
            return 0
        }
        
        let width = cgImage.width
        let height = cgImage.height
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        let count = width * height * bytesPerPixel
        var rawData = [UInt8](repeating: 0, count: count)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(data: &rawData,
                                      width: width,
                                      height: height,
                                      bitsPerComponent: 8,
                                      bytesPerRow: bytesPerRow,
                                      space: colorSpace,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue) else {
            return 0
        }
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        let inputSize = width * height * 3
        var inputData = [Float](repeating: 0, count: inputSize)
        var index = 0
        for y in 0..<height {
            for x in 0..<width {
                let pixelIndex = (y * width + x) * 4
                let r = Float(rawData[pixelIndex])
                let g = Float(rawData[pixelIndex + 1])
                let b = Float(rawData[pixelIndex + 2])
                inputData[index] = b - 104
                inputData[index + 1] = g - 117
                inputData[index + 2] = r - 123
                index += 3
            }
        }
        
        let data = Data(buffer: UnsafeBufferPointer(start: &inputData, count: inputData.count))
        do {
            try interpreter.copy(data, toInputAt: 0)
            try interpreter.invoke()
            let output = try interpreter.output(at: 0)
            let results = [Float](unsafeData: output.data) ?? []
            if results.count >= 2 {
                return results[1]
            } else if results.count == 1 {
                return results[0]
            }
            return 0
        } catch {
            print("NSFW inference failed: \(error)")
            return 0
        }
    }
    
    func checkNsfw(inputPath: String, result: @escaping FlutterResult) {
        DispatchQueue.global(qos: .userInitiated).async {
            guard self.setupNsfwInterpreter() else {
                DispatchQueue.main.async {
                    result(FlutterError(code: "NSFW_MODEL_ERROR", message: "Failed to load NSFW model", details: nil))
                }
                return
            }
            
            let url = URL(fileURLWithPath: inputPath)
            let asset = AVAsset(url: url)
            let duration = asset.duration
            let durationSeconds = CMTimeGetSeconds(duration)
            if durationSeconds <= 0 {
                DispatchQueue.main.async {
                    result(FlutterError(code: "NO_FRAMES", message: "Invalid video duration", details: nil))
                }
                return
            }
            
            let durationMs = Int(durationSeconds * 1000)
            let maxFrames = 100
            let framesToSample = min(maxFrames, max(1, durationMs / 250))
            if framesToSample <= 0 {
                DispatchQueue.main.async {
                    result(FlutterError(code: "NO_FRAMES", message: "No frames to sample", details: nil))
                }
                return
            }
            
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            
            var maxProb: Float = 0
            var sumProb: Float = 0
            var used = 0
            
            for i in 0..<framesToSample {
                autoreleasepool {
                    let tMs = Double(i) + 0.5
                    let timeMs = tMs * Double(durationMs) / Double(framesToSample)
                    let timeSec = timeMs / 1000.0
                    let time = CMTime(seconds: timeSec, preferredTimescale: 600)
                    do {
                        let cgImage = try generator.copyCGImage(at: time, actualTime: nil)
                        let image = UIImage(cgImage: cgImage)
                        let prob = self.classifyFrame(image)
                        sumProb += prob
                        if prob > maxProb {
                            maxProb = prob
                        }
                        used += 1
                    } catch {
                    }
                }
            }
            
            if used == 0 {
                DispatchQueue.main.async {
                    result(FlutterError(code: "NO_VALID_FRAMES", message: "Failed to decode frames", details: nil))
                }
                return
            }
            
            let finalScore = maxProb
            let score = Double(finalScore)
            print("NSFW check iOS: frames=\(used) maxProb=\(maxProb) avgProb=\(sumProb / Float(used))")
            DispatchQueue.main.async {
                result(score)
            }
        }
    }
    
    private func resizeImage(image: UIImage, size: CGSize) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(size, false, 1.0)
        image.draw(in: CGRect(origin: .zero, size: size))
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return newImage
    }
    
    private func centerCrop(image: UIImage, size: CGSize) -> UIImage? {
        guard let cgImage = image.cgImage else {
            return nil
        }
        let width = CGFloat(cgImage.width)
        let height = CGFloat(cgImage.height)
        let cropWidth = size.width
        let cropHeight = size.height
        let x = max((width - cropWidth) / 2.0, 0)
        let y = max((height - cropHeight) / 2.0, 0)
        let rect = CGRect(x: x, y: y, width: min(cropWidth, width - x), height: min(cropHeight, height - y))
        guard let croppedCg = cgImage.cropping(to: rect) else {
            return nil
        }
        return UIImage(cgImage: croppedCg)
    }
}

private extension Array where Element == Float {
    init?(unsafeData: Data) {
        let count = unsafeData.count / MemoryLayout<Float>.stride
        self = unsafeData.withUnsafeBytes { pointer in
            let buffer = pointer.bindMemory(to: Float.self)
            return Array(buffer[0..<count])
        }
    }
}
