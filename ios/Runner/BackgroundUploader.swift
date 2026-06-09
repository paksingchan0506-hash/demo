import Foundation
import UIKit
import Flutter

class BackgroundUploader: NSObject, URLSessionTaskDelegate, URLSessionDataDelegate {
    static let shared = BackgroundUploader()
    private var bgSession: URLSession!
    private var completionHandler: (() -> Void)?
    private var channel: FlutterMethodChannel?
    
    private override init() {
        super.init()
        let config = URLSessionConfiguration.background(withIdentifier: "com.example.realvideo.bgupload")
        config.sessionSendsLaunchEvents = true
        config.isDiscretionary = false
        bgSession = URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }
    
    func attachChannel(_ ch: FlutterMethodChannel) {
        self.channel = ch
    }
    
    func setCompletionHandler(_ handler: @escaping () -> Void) {
        completionHandler = handler
    }
    
    func start(filePath: String, presignedUrl: String, bucket: String, objectKey: String) {
        guard let fileUrl = URL(string: "file://\(filePath)") ?? URL(fileURLWithPath: filePath) as URL?,
              let url = URL(string: presignedUrl) else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "PUT"
        let task = bgSession.uploadTask(with: req, fromFile: fileUrl)
        task.resume()
    }
    
    func startPart(filePath: String, offset: Int, length: Int, presignedUrl: String, uploadId: String, partNumber: Int) {
        guard let url = URL(string: presignedUrl) else { return }
        // Create temp chunk file
        let src = URL(fileURLWithPath: filePath)
        let chunkUrl = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("part_\(uploadId)_\(partNumber).bin")
        do {
            let fh = try FileHandle(forReadingFrom: src)
            try fh.seek(toOffset: UInt64(offset))
            let data = try fh.read(upToCount: length) ?? Data()
            try data.write(to: chunkUrl, options: .atomic)
            try fh.close()
        } catch {
            channel?.invokeMethod("uploadFailed", arguments: "Create chunk failed: \(error.localizedDescription)")
            return
        }
        var req = URLRequest(url: url)
        req.httpMethod = "PUT"
        let task = bgSession.uploadTask(with: req, fromFile: chunkUrl)
        task.taskDescription = "\(uploadId)|\(partNumber)"
        task.resume()
    }
    
    // MARK: URLSession Delegates
    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        completionHandler?()
        completionHandler = nil
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        DispatchQueue.main.async { [weak self] in
            guard let ch = self?.channel else { return }
            if let err = error {
                ch.invokeMethod("uploadFailed", arguments: err.localizedDescription)
            } else if let httpResp = task.response as? HTTPURLResponse,
                      let eTag = httpResp.allHeaderFields["ETag"] as? String,
                      let desc = task.taskDescription, desc.contains("|") {
                let comps = desc.split(separator: "|")
                let uploadId = String(comps.first ?? "")
                let partNumber = Int(comps.last ?? "0") ?? 0
                ch.invokeMethod("uploadPartCompleted", arguments: ["uploadId": uploadId, "partNumber": partNumber, "eTag": eTag])
            } else if let reqUrl = task.currentRequest?.url,
                      let comps = URLComponents(url: reqUrl, resolvingAgainstBaseURL: false),
                      let host = comps.host,
                      let path = comps.percentEncodedPath.removingPercentEncoding {
                // Convert presigned URL back to s3://bucket/key
                let parts = host.split(separator: ".")
                let bucket = String(parts.first ?? "")
                let key = String(path.dropFirst()) // remove leading '/'
                let s3 = "s3://\(bucket)/\(key)"
                ch.invokeMethod("uploadCompleted", arguments: s3)
            }
        }
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
        DispatchQueue.main.async { [weak self] in
            guard let ch = self?.channel else { return }
            let sent = totalBytesSent > 0 ? totalBytesSent : 0
            let total = totalBytesExpectedToSend > 0 ? totalBytesExpectedToSend : 1
            ch.invokeMethod("uploadProgress", arguments: ["bytes": sent, "total": total])
        }
    }
}
