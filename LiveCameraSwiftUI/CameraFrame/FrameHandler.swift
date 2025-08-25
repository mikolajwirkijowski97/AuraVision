import Vision
import AVFoundation
import CoreImage
import CoreImage.CIFilterBuiltins

class FrameHandler: NSObject, ObservableObject {
    @Published var frame: CGImage?
    private var permissionGranted = true
    private let captureSession = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "sessionQueue")
    private let context = CIContext()
    
    // Create a single VNRequest handler and a lazy seg request
    private let visionQueue = DispatchQueue(label: "visionQueue")
    private lazy var personSegmentationRequest: VNGeneratePersonSegmentationRequest = {
        let request =  VNGeneratePersonSegmentationRequest()
        request.qualityLevel = .balanced
        return request
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
        let processedImage = self.postProcessFrame(frame: image)
        
        // Render the bitmap
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
    
    private func applyZoomBlur(image: CIImage) -> CIImage {
        let zoomBlurFilter = CIFilter.zoomBlur()
        zoomBlurFilter.inputImage = image
        zoomBlurFilter.center = CGPoint(x: image.extent.midX, y: image.extent.midY)
        zoomBlurFilter.amount = 10

        return zoomBlurFilter.outputImage ?? image
    }
    
    private func transformMaskToFitOriginal(mask: CIImage, originalExtent: CGRect) -> CIImage {
        let maskScaleX = originalExtent.width / mask.extent.width
        let maskScaleY = originalExtent.height / mask.extent.height
        return mask.transformed(by: .init(scaleX: maskScaleX, y: maskScaleY))
    }
    
    private func compositeMaskAndOriginalImage(mask: CIImage, originalImage: CIImage) -> CIImage {
        let additionCompositeFilter = CIFilter.additionCompositing()
        additionCompositeFilter.inputImage = originalImage
        additionCompositeFilter.backgroundImage = mask
        
        return additionCompositeFilter.outputImage ?? originalImage
    }

    private func postProcessFrame(frame: CIImage) -> CIImage {
        let handler = VNImageRequestHandler(ciImage: frame)
        
        do {
            try handler.perform([personSegmentationRequest])
            
            guard let mask = personSegmentationRequest.results?.first?.pixelBuffer else {
                return frame
            }

            let originalCIImage = frame
            var maskCIImage = CIImage(cvPixelBuffer: mask)
            
            maskCIImage = transformMaskToFitOriginal(mask: maskCIImage, originalExtent: originalCIImage.extent)
            maskCIImage = applyZoomBlur(image: maskCIImage)
            
            let compositeImage = compositeMaskAndOriginalImage(mask: maskCIImage, originalImage: originalCIImage)

            return compositeImage
            
        } catch {
            print("Vision request failed: \(error)")
            return frame
        }
    }
}
