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
        let size = jfaPassImage.extent.size
        let diag = Float(hypot(size.width, size.height))
        decodeFilter.normalizationFactor = diag
        
        return decodeFilter.outputImage ?? jfaPassImage
    }
}

// MARK: - Private CIFilter Subclasses

/// A filter that creates the initial seed map from a mask.
private class JfaSeedFilter: MetalCIFilter {
    init() {
        // We'll supply the image size at render time via `outputImage` so start with empty args.
        super.init(resourceName: "JFA", functionName: "jfaSeedKernel", arguments: [])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var outputImage: CIImage? {
        guard let inputImage = inputImage else { return nil }
        let size = inputImage.extent.size
        // Pass imageSize as a CIVector (maps to float2 in the Metal kernel).
        self.arguments = [CIVector(x: size.width, y: size.height)]
        return super.outputImage
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
        guard let inputImage = inputImage else { return nil }
        let size = inputImage.extent.size
        // Pass jfaLevel then imageSize (as CIVector) matching the Metal signature.
        self.arguments = [jfaLevel, CIVector(x: size.width, y: size.height)]
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
        guard let inputImage = inputImage else { return nil }
        let size = inputImage.extent.size
        // Pass normalizationFactor then imageSize to match Metal kernel signature.
        self.arguments = [normalizationFactor, CIVector(x: size.width, y: size.height)]
        return super.outputImage
    }
}
