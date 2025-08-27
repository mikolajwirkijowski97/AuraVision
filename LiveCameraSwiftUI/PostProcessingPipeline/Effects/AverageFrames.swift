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
    
    /// A buffer to store the history of recent frames.
    private var frames: [CIImage]
    
    /// The most recently calculated average image, which represents the running state.
    private var currentAverage: CIImage?
    
    init(frameCount: Int) {
        self.frameCount = frameCount
        self.frames = []
    }
    
    /// Applies the moving average effect to an incoming image.
    /// This method must be `mutating` as it modifies the struct's internal state
    /// (`frames` and `currentAverage`).
    func apply(to image: CIImage) -> CIImage {
        if frames.isEmpty {
            frames = Array(repeating: image, count: frameCount)
        }

        frames.append(image)
        let oldestImage = frames.removeFirst()
        
        // Create the custom filter with the images needed for the formula.
        let filter = AverageFramesFilter(
            inputImage: image,
            oldestImage: oldestImage,
            currentImage: currentAverage ?? image,
            frameCount: frameCount
        )
        
        // Apply the filter. The runningAverage from the previous step is passed
        // as the main input image, which corresponds to `currentPixelColor` in the Metal shader.
        let newAverage = filter.outputImage ?? image
        
        // Update our state with the new average for the next iteration.
        self.currentAverage = newAverage
        
        return newAverage
    }
}
class AverageFramesFilter: MetalCIFilter {

    init(inputImage: CIImage, oldestImage: CIImage, currentImage: CIImage, frameCount: Int) {
        super.init(
            resourceName: "AverageFrames",
            functionName: "averageFrames",
            arguments: [oldestImage, currentImage, frameCount]
        )
        self.inputImage = inputImage
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
