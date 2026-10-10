import UIKit
import Flutter
import Vision

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {

    private static let ocrChannel = "auto_ledger/ocr"

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        GeneratedPluginRegistrant.register(with: self)

        guard let controller = window?.rootViewController as? FlutterViewController else {
            return super.application(application, didFinishLaunchingWithOptions: launchOptions)
        }

        let channel = FlutterMethodChannel(
            name: AppDelegate.ocrChannel,
            binaryMessenger: controller.binaryMessenger
        )
        channel.setMethodCallHandler { call, result in
            switch call.method {
            case "isAvailable":
                result(true)
            case "recognizeText":
                guard let args = call.arguments as? [String: Any],
                      let path = args["path"] as? String else {
                    result(FlutterError(code: "NO_PATH", message: "缺少图片路径", details: nil))
                    return
                }
                AppDelegate.recognize(path: path, result: result)
            default:
                result(FlutterMethodNotImplemented)
            }
        }

        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    /// Vision 中文文字识别（iOS 13+ 支持 zh-Hans）
    private static func recognize(path: String, result: @escaping FlutterResult) {
        guard let image = UIImage(contentsOfFile: path), let cg = image.cgImage else {
            result(FlutterError(code: "BAD_IMAGE", message: "无法读取图片", details: nil))
            return
        }

        let request = VNRecognizeTextRequest { request, error in
            if let error = error {
                result(FlutterError(code: "OCR_FAIL", message: error.localizedDescription, details: nil))
                return
            }
            let observations = request.results as? [VNRecognizedTextObservation] ?? []
            // 按视觉位置从上到下排序，尽量还原账单行序
            let sorted = observations.sorted { a, b in
                a.boundingBox.origin.y > b.boundingBox.origin.y
            }
            let text = sorted
                .compactMap { $0.topCandidates(1).first?.string }
                .joined(separator: "\n")
            result(text)
        }
        request.recognitionLanguages = ["zh-Hans", "en-US"]
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false

        DispatchQueue.global(qos: .userInitiated).async {
            let handler = VNImageRequestHandler(cgImage: cg, options: [:])
            do {
                try handler.perform([request])
            } catch {
                result(FlutterError(code: "OCR_FAIL", message: error.localizedDescription, details: nil))
            }
        }
    }
}
