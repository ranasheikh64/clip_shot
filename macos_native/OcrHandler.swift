import Cocoa
import FlutterMacOS
import Vision

// Registers a MethodChannel "com.snapocr/ocr" that runs on-device
// text recognition using Apple's Vision framework (VNRecognizeTextRequest).
// No network calls, works offline, very accurate for screenshots.
//
// Wiring instructions (see README.md "macOS setup"):
// 1. Drop this file into macos/Runner/OcrHandler.swift
// 2. Call OcrHandler.register(with: flutterViewController) from
//    MainFlutterWindow.swift's awakeFromNib(), after the controller is created.

class OcrHandler: NSObject {

    static func register(with controller: FlutterViewController) {
        let channel = FlutterMethodChannel(
            name: "com.snapocr/ocr",
            binaryMessenger: controller.engine.binaryMessenger
        )
        channel.setMethodCallHandler { call, result in
            switch call.method {
            case "recognizeText":
                guard let args = call.arguments as? [String: Any],
                      let bytes = args["imageBytes"] as? FlutterStandardTypedData else {
                    result(FlutterError(code: "BAD_ARGS", message: "imageBytes missing", details: nil))
                    return
                }
                recognizeText(data: bytes.data) { text, error in
                    if let error = error {
                        result(FlutterError(code: "OCR_FAILED", message: error.localizedDescription, details: nil))
                    } else {
                        result(text ?? "")
                    }
                }
            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }

    private static func recognizeText(data: Data, completion: @escaping (String?, Error?) -> Void) {
        guard let nsImage = NSImage(data: data),
              let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            completion(nil, NSError(domain: "OcrHandler", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not decode image"]))
            return
        }

        let request = VNRecognizeTextRequest { request, error in
            if let error = error {
                completion(nil, error)
                return
            }
            guard let observations = request.results as? [VNRecognizedTextObservation] else {
                completion("", nil)
                return
            }
            let lines = observations.compactMap { $0.topCandidates(1).first?.string }
            completion(lines.joined(separator: "\n"), nil)
        }
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try handler.perform([request])
            } catch {
                completion(nil, error)
            }
        }
    }
}
