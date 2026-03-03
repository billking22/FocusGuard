import AVFoundation
import CoreImage
import AppKit

@MainActor
class CameraManager: NSObject {
    static let shared = CameraManager()

    private let captureSession = AVCaptureSession()
    private var videoOutput: AVCaptureVideoDataOutput?
    private var completionHandler: ((CGImage?) -> Void)?
    private let processingQueue = DispatchQueue(label: "com.focusguard.camera", qos: .userInitiated)
    // 帧跳过计数器，在 processingQueue 上访问
    nonisolated(unsafe) private var framesToSkip: Int = 0

    private override init() {
        super.init()
        setupSession()
    }

    private func setupSession() {
        captureSession.beginConfiguration()
        captureSession.sessionPreset = .high

        guard let camera = AVCaptureDevice.default(for: .video) else {
            print("[CameraManager] ❌ 未找到摄像头设备")
            captureSession.commitConfiguration()
            return
        }

        do {
            let input = try AVCaptureDeviceInput(device: camera)
            if captureSession.canAddInput(input) {
                captureSession.addInput(input)
                print("[CameraManager] ✅ 摄像头输入已添加")
            } else {
                print("[CameraManager] ❌ 无法添加摄像头输入")
                captureSession.commitConfiguration()
                return
            }

            let output = AVCaptureVideoDataOutput()
            output.setSampleBufferDelegate(self, queue: processingQueue)
            output.alwaysDiscardsLateVideoFrames = true

            let pixelFormat = kCVPixelFormatType_32BGRA
            if output.availableVideoPixelFormatTypes.contains(pixelFormat) {
                output.videoSettings = [
                    kCVPixelBufferPixelFormatTypeKey as String: pixelFormat
                ]
            }

            if captureSession.canAddOutput(output) {
                captureSession.addOutput(output)
                self.videoOutput = output
            } else {
                print("[CameraManager] ❌ 无法添加视频输出")
                captureSession.commitConfiguration()
                return
            }
        } catch {
            print("[CameraManager] ❌ 设置失败: \(error)")
            captureSession.commitConfiguration()
            return
        }

        captureSession.commitConfiguration()
        print("[CameraManager] ✅ Camera session configured")
    }

    func captureFrame() async throws -> CGImage? {
        guard videoOutput != nil else {
            print("[CameraManager] ❌ 视频输出未初始化")
            throw CameraError.setupFailed
        }

        print("[CameraManager] 📸 开始捕获帧...")

        // 跳过前 10 帧让摄像头传感器预热（约 0.3 秒@30fps）
        framesToSkip = 10

        if !captureSession.isRunning {
            captureSession.startRunning()
        }

        return try await withCheckedThrowingContinuation { continuation in
            self.completionHandler = { image in
                continuation.resume(returning: image)
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                if self.completionHandler != nil {
                    print("[CameraManager] ⚠️ 捕获超时，停止会话")
                    self.captureSession.stopRunning()
                    self.completionHandler?(nil)
                    self.completionHandler = nil
                }
            }
        }
    }

    func stopCapture() {
        if captureSession.isRunning {
            captureSession.stopRunning()
            print("[CameraManager] ⏹️ 摄像头会话已停止")
        }
    }

    func checkAuthorization() async -> Bool {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        print("[CameraManager] 🔐 摄像头权限状态: \(status)")

        switch status {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .video)
        case .denied, .restricted:
            return false
        @unknown default:
            return false
        }
    }
}

extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    nonisolated func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        // 在 processingQueue 上同步检查帧跳过计数（等摄像头传感器曝光调整）
        if framesToSkip > 0 {
            framesToSkip -= 1
            return
        }

        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            Task { @MainActor in
                print("[CameraManager] ❌ 无法获取图像缓冲区")
                self.completionHandler?(nil)
                self.completionHandler = nil
            }
            return
        }

        let width = CVPixelBufferGetWidth(imageBuffer)
        let height = CVPixelBufferGetHeight(imageBuffer)
        let pixelFormat = CVPixelBufferGetPixelFormatType(imageBuffer)

        // 在同步上下文中完成图像转换，确保 pixel buffer 数据有效
        var cgImage: CGImage?

        if pixelFormat == kCVPixelFormatType_32BGRA {
            CVPixelBufferLockBaseAddress(imageBuffer, .readOnly)
            defer { CVPixelBufferUnlockBaseAddress(imageBuffer, .readOnly) }

            guard let baseAddress = CVPixelBufferGetBaseAddress(imageBuffer) else {
                Task { @MainActor in
                    print("[CameraManager] ❌ 无法获取基地址")
                    self.completionHandler?(nil)
                    self.completionHandler = nil
                }
                return
            }

            let bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer)
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)

            guard let context = CGContext(
                data: baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: colorSpace,
                bitmapInfo: bitmapInfo.rawValue
            ) else {
                Task { @MainActor in
                    print("[CameraManager] ❌ 无法创建 CGContext")
                    self.completionHandler?(nil)
                    self.completionHandler = nil
                }
                return
            }

            cgImage = context.makeImage()
        } else {
            let ciImage = CIImage(cvPixelBuffer: imageBuffer)
            let context = CIContext(options: nil)
            cgImage = context.createCGImage(ciImage, from: ciImage.extent)
        }

        guard let finalImage = cgImage else {
            Task { @MainActor in
                print("[CameraManager] ❌ 无法创建 CGImage")
                self.completionHandler?(nil)
                self.completionHandler = nil
            }
            return
        }

        Task { @MainActor in
            print("[CameraManager] ✅ Frame captured: \(width)x\(height)")
            self.captureSession.stopRunning()
            self.completionHandler?(finalImage)
            self.completionHandler = nil
        }
    }

    nonisolated func captureOutput(
        _ output: AVCaptureOutput,
        didDrop sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {}
}

enum CameraError: Error {
    case setupFailed
    case captureFailed
    case notAuthorized
}
