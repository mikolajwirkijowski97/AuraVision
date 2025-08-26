import Vision
import CoreImage
import AVFoundation


class FrameHandler: NSObject, ObservableObject {
    @Published var frame: CGImage?
    private var permissionGranted = true
    private let captureSession = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "sessionQueue")
    private let context = CIContext()
    
    // Create a single VNRequest handler
    private let visionQueue = DispatchQueue(label: "visionQueue")
    
    // The pipeline for image post-processing
    lazy var postProcessingPipeline: PostProcessingPipeline = {
        var effects: [PostProcessingEffect] = [ZoomBlur(intensity: 10), SubtractHalf()]
        
        return PostProcessingPipeline(effects: effects)
    }()
    
    override init() {
        super.init()
        self.checkPermission()
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            self.setupCaptureSession()
            self.captureSession.startRunning()
        }
    }
    
    private func checkPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            self.permissionGranted = true
        case .notDetermined:
            self.requestPermission()
        default:
            self.permissionGranted = false
        }
    }
    
    private func requestPermission() {
        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            self?.permissionGranted = granted
        }
    }
    
    private func setupCaptureSession() {
        let videoOutput = AVCaptureVideoDataOutput()
        
        guard permissionGranted else { return }
        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else { return }
        guard let videoDeviceInput = try? AVCaptureDeviceInput(device: videoDevice) else { return }
        guard captureSession.canAddInput(videoDeviceInput) else { return }
        captureSession.addInput(videoDeviceInput)
        
        videoOutput.setSampleBufferDelegate(self, queue: visionQueue)
        videoOutput.alwaysDiscardsLateVideoFrames = true
        captureSession.addOutput(videoOutput)
        
        videoOutput.connection(with: .video)?.videoRotationAngle = 90.0
    }
}

extension FrameHandler: AVCaptureVideoDataOutputSampleBufferDelegate {
    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let image = imageFromSampleBuffer(sampleBuffer: sampleBuffer) else { return }
        let processedImage = postProcessingPipeline.apply(to: image)
        
        // Render processed image to a bitmap
        let renderedImage = context.createCGImage(processedImage, from: processedImage.extent)!
        DispatchQueue.main.async { [weak self] in
            self?.frame = renderedImage
        }
    }
    
    private func imageFromSampleBuffer(sampleBuffer: CMSampleBuffer) -> CIImage? {
        let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)!
        let attachments = CMCopyDictionaryOfAttachments(allocator: kCFAllocatorDefault,
                                                        target: imageBuffer,
                                                        attachmentMode: CMAttachmentMode(kCMAttachmentMode_ShouldPropagate)) as? [CIImageOption: Any]
        let ciImage = CIImage(cvPixelBuffer: imageBuffer, options: attachments)
        
        return ciImage
    }
}
