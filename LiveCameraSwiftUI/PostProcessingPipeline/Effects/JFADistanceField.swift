//
//  JfaDistanceField.swift
//  LiveCameraSwiftUI
//
//  Created by Mikołaj Wirkijowski on 02/09/2025.
//

import CoreImage

/// A post-processing effect that generates a visible distance field from a grayscale mask
/// using a multi-pass Jump Flooding Algorithm (JFA).
struct JfaDistanceFieldEffect: PostProcessingEffect {

    /// The number of JFA passes to perform. Should match `c_maxSteps` in the Metal shader.
    var steps: Int = 10
    
    /// A value to normalize the final distance by, mapping it to a [0, 1] grayscale range.
    /// A good starting point is a fraction of the image's diagonal size.
    var normalizationFactor: Float = 50000.0

    func apply(to image: CIImage) -> CIImage {
        // STAGE 1: Convert the input mask into an encoded seed map.
        let seedFilter = JfaSeedFilter()
        seedFilter.inputImage = image
        guard var jfaPassImage = seedFilter.outputImage else {
            return image
        }

        // STAGE 2: Iteratively apply the JFA step kernel.
        let stepFilter = JfaStepFilter()
        for i in 0..<steps {
            stepFilter.inputImage = jfaPassImage
            stepFilter.jfaLevel = Float(i)
            
            guard let nextImage = stepFilter.outputImage else {
                // If a pass fails, return the last successful image.
                return jfaPassImage
            }
            jfaPassImage = nextImage
        }
        
        // STAGE 3: Decode the final JFA data into a visible grayscale distance map.
        let decodeFilter = JfaDecodeFilter()
        decodeFilter.inputImage = jfaPassImage
        decodeFilter.normalizationFactor = self.normalizationFactor
        
        return decodeFilter.outputImage ?? jfaPassImage
    }
}

// MARK: - Private CIFilter Subclasses

/// A filter that creates the initial seed map from a mask.
private class JfaSeedFilter: MetalCIFilter {
    init() {
        super.init(resourceName: "JFA", functionName: "jfaSeedKernel")
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

/// A filter that applies a single JFA step.
private class JfaStepFilter: MetalCIFilter {
    var jfaLevel: Float = 0.0

    init() {
        // Initialize with an empty arguments array, which we will populate before rendering.
        super.init(resourceName: "JFA", functionName: "jfaStepKernel", arguments: [])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var outputImage: CIImage? {
        // Set the kernel argument just before applying the filter.
        self.arguments = [jfaLevel]
        return super.outputImage
    }
}

/// A filter that decodes the final JFA map into a visible image.
private class JfaDecodeFilter: MetalCIFilter {
    var normalizationFactor: Float = 256.0

    init() {
        super.init(resourceName: "JFA", functionName: "jfaDecodeKernel", arguments: [])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var outputImage: CIImage? {
        self.arguments = [normalizationFactor]
        return super.outputImage
    }
}
