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
    
    // Create a single VNRequest handler and a single request to reuse
    private let visionQueue = DispatchQueue(label: "visionQueue")

    override init() {
        super.init()
        
        
        self.checkPermission()
        sessionQueue.async { [unowned self] in
            self.setupCaptureSession()
            self.captureSession.startRunning()
        }
    }
    
    func checkPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            self.permissionGranted = true
        case .notDetermined:
            self.requestPermission()
        default:
            self.permissionGranted = false
        }
    }
    
    func requestPermission() {
        AVCaptureDevice.requestAccess(for: .video) { [unowned self] granted in
            self.permissionGranted = granted
        }
    }
    
    func setupCaptureSession() {
        let videoOutput = AVCaptureVideoDataOutput()
        
        guard permissionGranted else { return }
        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else { return }
        guard let videoDeviceInput = try? AVCaptureDeviceInput(device: videoDevice) else { return }
        guard captureSession.canAddInput(videoDeviceInput) else { return }
        captureSession.addInput(videoDeviceInput)
        
        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "sampleBufferQueue"))
        captureSession.addOutput(videoOutput)
        
        videoOutput.connection(with: .video)?.videoRotationAngle = 90.0
    }
}


extension FrameHandler: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let cgImage = imageFromSampleBuffer(sampleBuffer: sampleBuffer) else { return }
        
        let processedImage = self.postProcessFrame(frame: cgImage)
        DispatchQueue.main.async {
            self.frame = processedImage
        }
    }
    
    private func imageFromSampleBuffer(sampleBuffer: CMSampleBuffer) -> CGImage? {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return nil }
        let ciImage = CIImage(cvPixelBuffer: imageBuffer)
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return nil }
        
        return cgImage
    }
    
    func transformMaskToFitOriginal(mask: CIImage, originalExtent: CGRect) -> CIImage {
        let maskScaleX = originalExtent.width / mask.extent.width
        let maskScaleY = originalExtent.height / mask.extent.height
        return mask.transformed(by: .init(scaleX: maskScaleX, y: maskScaleY))
    }
    
    func compositeMaskAndOriginalImage(mask: CIImage, originalImage: CIImage) -> CGImage {
        let additionCompositeFilter = CIFilter.additionCompositing()
        additionCompositeFilter.inputImage = originalImage
        additionCompositeFilter.backgroundImage = mask
        
        if let output = additionCompositeFilter.outputImage {
            let ret = context.createCGImage(output, from: originalImage.extent)!
            return ret
        } else {
            return context.createCGImage(originalImage, from: originalImage.extent)!
        }
    }

    private func postProcessFrame(frame: CGImage) -> CGImage {
        let handler = VNImageRequestHandler(cgImage: frame)
        
        let personSegmentationRequest = VNGeneratePersonSegmentationRequest()
        // Configure the Vision request once
        personSegmentationRequest.qualityLevel = .balanced
        do {
            try handler.perform([personSegmentationRequest])

            guard let mask = personSegmentationRequest.results?.first?.pixelBuffer else {
                // If no mask is found, return the original frame
                print("Returning original frame")
                return frame
            }

            let originalCIImage = CIImage(cgImage: frame)
            var maskCIImage = CIImage(cvPixelBuffer: mask)
            
            maskCIImage = transformMaskToFitOriginal(mask: maskCIImage, originalExtent: originalCIImage.extent)
            return compositeMaskAndOriginalImage(mask: maskCIImage, originalImage: originalCIImage)
        } catch {
            // If any errors occur, just return the original frame
            print("Vision request failed: \(error)")
            return frame
        }
    }
}
