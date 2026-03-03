import Foundation
import Vision

struct LocalAnalysisResult {
    let hasFace: Bool
}

@MainActor
class LocalAnalyzer {

    func analyze(image: CGImage) async -> LocalAnalysisResult {
        // 将 Vision 处理移到后台线程，内置摄像头为镜像翻转图像
        let result = await Task.detached { () -> LocalAnalysisResult in
            // 前置摄像头帧通常是水平镜像的，优先用 upMirrored，失败再 fallback 到 up
            let orientations: [CGImagePropertyOrientation] = [.upMirrored, .up]

            for orientation in orientations {
                let request = VNDetectFaceRectanglesRequest()
                let handler = VNImageRequestHandler(cgImage: image, orientation: orientation, options: [:])

                do {
                    try handler.perform([request])
                    let results = request.results ?? []
                    if !results.isEmpty {
                        print("[LocalAnalyzer] ✅ Detected \(results.count) face(s) (orientation: \(orientation.rawValue))")
                        return LocalAnalysisResult(hasFace: true)
                    }
                } catch {
                    print("[LocalAnalyzer] ❌ Vision error: \(error.localizedDescription)")
                }
            }

            print("[LocalAnalyzer] 👤 No face detected")
            return LocalAnalysisResult(hasFace: false)
        }.value

        return result
    }
}
