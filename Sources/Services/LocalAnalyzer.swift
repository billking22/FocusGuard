import Foundation
import Vision
import CoreImage

struct LocalAnalysisResult {
    let hasFace: Bool
}

@MainActor
class LocalAnalyzer {
    private let faceDetectionRequest: VNDetectFaceRectanglesRequest

    init() {
        self.faceDetectionRequest = VNDetectFaceRectanglesRequest()
        self.faceDetectionRequest.revision = VNDetectFaceRectanglesRequestRevision3
        print("[LocalAnalyzer] ✅ Vision 人脸检测初始化完成")
    }

    func analyze(image: CGImage) async -> LocalAnalysisResult {
        print("[LocalAnalyzer] 📸 开始人脸检测... (图像: \(image.width)x\(image.height))")

        let handler = VNImageRequestHandler(cgImage: image, options: [:])

        do {
            try handler.perform([faceDetectionRequest])
            print("[LocalAnalyzer] ✅ Vision 请求执行完成")

            guard let results = faceDetectionRequest.results as? [VNFaceObservation] else {
                print("[LocalAnalyzer] ⚠️ 结果类型转换失败")
                return LocalAnalysisResult(hasFace: false)
            }

            print("[LocalAnalyzer] 📊 检测到 \(results.count) 个人脸")

            if results.isEmpty {
                print("[LocalAnalyzer] 👤 未检测到人脸")
                return LocalAnalysisResult(hasFace: false)
            }

            for (index, observation) in results.enumerated() {
                let confidence = Double(observation.confidence)
                print("[LocalAnalyzer]   人脸 #\(index + 1): 置信度=\(String(format: "%.2f", confidence)), boundingBox=\(observation.boundingBox)")
            }

            print("[LocalAnalyzer] ✅ 检测到人脸")
            return LocalAnalysisResult(hasFace: true)

        } catch {
            print("[LocalAnalyzer] ❌ Vision 错误: \(error.localizedDescription)")
            return LocalAnalysisResult(hasFace: false)
        }
    }
}
