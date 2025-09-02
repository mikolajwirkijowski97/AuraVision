//
//  AverageFrames.swift
//  LiveCameraSwiftUI
//
//  Created by Mikołaj Wirkijowski on 26/08/2025.
//
import CoreImage

class AverageFrames: PostProcessingEffect {
    /// The number of frames to average over.
    let frameCount: Int
    
    /// The most recently calculated average image, which represents the running state.
    private var currentAverage: CIImage?
    
    /// Reusable filter instance to avoid recreating Metal kernels
    private let filter: AverageFramesFilter
    
    private let context = CIContext()
    
    init(frameCount: Int) {
        self.frameCount = frameCount
        // Create the filter once during initialization
        self.filter = AverageFramesFilter()
    }
    
    /// Applies the moving average effect to an incoming image.
    func apply(to image: CIImage) -> CIImage {
        
        // Update the filter's parameters
        filter.inputImage = image
        filter.currentImage = currentAverage ?? image
        filter.frameCount = frameCount
        
        let newAverage = filter.outputImage ?? image
        
        // TODO: Make this an MTLTexture with a linear colorspace in the future, might improve performance.
        let renderedNewAverage = context.createCGImage(newAverage, from: image.extent)!
        
        // Create the new CIImage from the rendered bitmap (its origin is at 0,0)
        let imageAtOrigin = CIImage(cgImage: renderedNewAverage)

        // Create a transform to move it back to the correct origin of the input image
        let transform = CGAffineTransform(translationX: image.extent.origin.x, y: image.extent.origin.y)

        // Apply the transform and store the correctly positioned image for the next frame
        self.currentAverage = imageAtOrigin.transformed(by: transform)
        
        return self.currentAverage ?? image
    }
}
class AverageFramesFilter: MetalCIFilter {
    
    @objc dynamic var oldestImage: CIImage?
    @objc dynamic var currentImage: CIImage?
    @objc dynamic var frameCount: Int = 0
    
    init() {
        super.init(
            resourceName: "AverageFrames",
            functionName: "averageFrames",
            arguments: []
        )
    }
    
    override var outputImage: CIImage? {
        guard let inputImage = inputImage,
              let currentImage = currentImage else {
            return nil
        }

        self.arguments = [currentImage, Float(frameCount)]

        return super.outputImage
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
