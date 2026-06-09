import Flutter
import UIKit
import AVFoundation

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var _savedScreenBrightness: CGFloat?
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    
    // Register MethodChannel for NSFW detection and 2D mask
    let controller : FlutterViewController = window?.rootViewController as! FlutterViewController
    let processorChannel = FlutterMethodChannel(name: "com.example.realvideo/processor", binaryMessenger: controller.binaryMessenger)
    let uploaderChannel = FlutterMethodChannel(name: "com.example.realvideo/uploader", binaryMessenger: controller.binaryMessenger)
    
    processorChannel.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
      switch call.method {
      case "checkNsfw":
        if let args = call.arguments as? [String: Any], let inputPath = args["inputPath"] as? String {
          VideoProcessor.shared.checkNsfw(inputPath: inputPath, result: result)
        } else {
          result(FlutterError(code: "INVALID_ARGS", message: "Missing or invalid arguments", details: nil))
        }
      case "processVideo":
        if let args = call.arguments as? [String: Any], let inputPath = args["inputPath"] as? String {
          VideoProcessor.shared.processVideo(inputPath: inputPath, result: result)
        } else {
          result(FlutterError(code: "INVALID_ARGS", message: "Missing or invalid arguments", details: nil))
        }
      case "processVideo2D":
        if let args = call.arguments as? [String: Any],
           let inputPath = args["inputPath"] as? String,
           let decorationType = args["decorationType"] as? String {
          VideoProcessor.shared.processVideo2D(inputPath: inputPath,
                                               decorationType: decorationType,
                                               result: result)
        } else {
          result(FlutterError(code: "INVALID_ARGS", message: "Missing or invalid arguments", details: nil))
        }
      case "getVideoInfo":
        if let args = call.arguments as? [String: Any], let inputPath = args["inputPath"] as? String {
          let url = URL(fileURLWithPath: inputPath)
          let asset = AVAsset(url: url)
          if let track = asset.tracks(withMediaType: .video).first {
            let size = track.naturalSize.applying(track.preferredTransform)
            let w = abs(size.width)
            let h = abs(size.height)
            let isPortrait = h > w
            let seconds = CMTimeGetSeconds(asset.duration)
            let durationMs = seconds.isFinite ? Int(seconds * 1000.0) : 0
            result([
              "width": Int(w),
              "height": Int(h),
              "isPortrait": isPortrait,
              "duration": durationMs,
            ])
          } else {
            result(FlutterError(code: "META_ERROR", message: "No video track", details: nil))
          }
        } else {
          result(FlutterError(code: "INVALID_ARGS", message: "Missing or invalid arguments", details: nil))
        }
      case "setScreenBrightness":
        if let args = call.arguments as? [String: Any], let brightness = args["brightness"] as? Double {
          DispatchQueue.main.async {
            if brightness < 0 {
              if let saved = self?._savedScreenBrightness {
                UIScreen.main.brightness = saved
                self?._savedScreenBrightness = nil
              }
            } else {
              if self?._savedScreenBrightness == nil {
                self?._savedScreenBrightness = UIScreen.main.brightness
              }
              UIScreen.main.brightness = CGFloat(max(0.0, min(1.0, brightness)))
            }
            result(true)
          }
        } else {
          result(FlutterError(code: "INVALID_ARGS", message: "Missing or invalid arguments", details: nil))
        }
      case "setKeepScreenOn":
        if let args = call.arguments as? [String: Any], let enabled = args["enabled"] as? Bool {
          DispatchQueue.main.async {
            UIApplication.shared.isIdleTimerDisabled = enabled
            result(true)
          }
        } else {
          result(FlutterError(code: "INVALID_ARGS", message: "Missing or invalid arguments", details: nil))
        }
      case "openUrl":
        if let args = call.arguments as? [String: Any], let urlString = args["url"] as? String, let url = URL(string: urlString) {
          DispatchQueue.main.async {
            UIApplication.shared.open(url, options: [:]) { ok in
              result(ok)
            }
          }
        } else {
          result(FlutterError(code: "INVALID_ARGS", message: "Missing or invalid arguments", details: nil))
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    
    BackgroundUploader.shared.attachChannel(uploaderChannel)
    uploaderChannel.setMethodCallHandler { (call: FlutterMethodCall, result: @escaping FlutterResult) in
      switch call.method {
      case "startBackgroundUpload":
        if let args = call.arguments as? [String: Any],
           let filePath = args["filePath"] as? String,
           let presignedUrl = args["presignedUrl"] as? String,
           let bucket = args["bucket"] as? String,
           let objectKey = args["objectKey"] as? String {
          BackgroundUploader.shared.start(filePath: filePath, presignedUrl: presignedUrl, bucket: bucket, objectKey: objectKey)
          result(true)
        } else {
          result(FlutterError(code: "INVALID_ARGS", message: "Missing args", details: nil))
        }
      case "startBackgroundUploadPart":
        if let args = call.arguments as? [String: Any],
           let filePath = args["filePath"] as? String,
           let offset = args["offset"] as? Int,
           let length = args["length"] as? Int,
           let presignedUrl = args["presignedUrl"] as? String,
           let uploadId = args["uploadId"] as? String,
           let partNumber = args["partNumber"] as? Int {
          BackgroundUploader.shared.startPart(filePath: filePath, offset: offset, length: length, presignedUrl: presignedUrl, uploadId: uploadId, partNumber: partNumber)
          result(true)
        } else {
          result(FlutterError(code: "INVALID_ARGS", message: "Missing args for part", details: nil))
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  override func application(_ application: UIApplication, handleEventsForBackgroundURLSession identifier: String, completionHandler: @escaping () -> Void) {
    BackgroundUploader.shared.setCompletionHandler(completionHandler)
  }
  
  // Removed applicationWillEnterForeground channel override to avoid overriding existing handlers
}
