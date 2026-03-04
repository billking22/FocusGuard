import Foundation
import Vision

struct LocalAnalysisResult {
    let hasFace: Bool
    let hasPerson: Bool

    var hasPresence: Bool {
        hasFace || hasPerson
    }
}

@MainActor
class LocalAnalyzer {

    func analyze(image: CGImage) async -> LocalAnalysisResult {
        // 将 Vision 处理移到后台线程，内置摄像头为镜像翻转图像
        let result = await Task.detached { () -> LocalAnalysisResult in
            // 前置摄像头帧通常是水平镜像的，优先用 upMirrored，失败再 fallback 到 up
            let orientations: [CGImagePropertyOrientation] = [.upMirrored, .up]
            var detectedFace = false
            var detectedPerson = false

            for orientation in orientations {
                let handler = VNImageRequestHandler(cgImage: image, orientation: orientation, options: [:])
                let faceRequest = VNDetectFaceRectanglesRequest()
                let humanRequest = VNDetectHumanRectanglesRequest()

                do {
                    try handler.perform([faceRequest, humanRequest])

                    let faceResults = faceRequest.results ?? []
                    let humanResults = humanRequest.results ?? []

                    if !faceResults.isEmpty {
                        detectedFace = true
                    }
                    if !humanResults.isEmpty {
                        detectedPerson = true
                    }

                    if detectedFace || detectedPerson {
                        print("[LocalAnalyzer] ✅ Presence detected: face=\(faceResults.count), human=\(humanResults.count), orientation=\(orientation.rawValue)")
                        return LocalAnalysisResult(hasFace: detectedFace, hasPerson: detectedPerson)
                    }
                } catch {
                    print("[LocalAnalyzer] ❌ Vision error: \(error.localizedDescription)")
                }
            }

            print("[LocalAnalyzer] 👤 No face/human detected")
            return LocalAnalysisResult(hasFace: false, hasPerson: false)
        }.value

        return result
    }
}
