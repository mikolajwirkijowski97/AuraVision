//
//  JFADistance.swift
//  LiveCameraSwiftUI
//
//  Created by Roo (AI) on 02/09/2025.
//

import CoreImage
import CoreImage.CIFilterBuiltins

// JFA-based unsigned distance map from a binary mask.
// - Occupied if any RGB channel > threshold (default 0.2)
// - Output is grayscale [0,1], representing absolute (unsigned) distance normalized by image diagonal.
struct JFADistance: PostProcessingEffect {
    var threshold: Float = 0.2
    
    func apply(to image: CIImage) -> CIImage {
        // Preprocess: clamp input to [0,1] to make mask values predictable
        let clamp = CIFilter.colorClamp()
        clamp.inputImage = image
        clamp.minComponents = CIVector(x: 0, y: 0, z: 0, w: 0)
        clamp.maxComponents = CIVector(x: 1, y: 1, z: 1, w: 1)
        let clampedMask = clamp.outputImage ?? image
        
        // 1) Seed initialization from mask
        let initFilter = JFAInitSeedsFilter()
        initFilter.inputImage = clampedMask
        initFilter.threshold = threshold
        
        guard var seeds = initFilter.outputImage else {
            return clampedMask
        }
        
        // 2) Jump Flood iterations, from largest power-of-two step down to 1
        let size = clampedMask.extent.size
        let steps = JFADistance.makeJFASteps(for: size)
        let stepFilter = JFAStepFilter()
        for s in steps {
            stepFilter.inputImage = seeds
            stepFilter.step = Float(s)
            stepFilter.imgSize = size
            if let out = stepFilter.outputImage {
                seeds = out
            }
        }
        
        // 3) Finalize into grayscale distance map normalized by diagonal length
        let diag = Float(hypot(size.width, size.height))
        let finalize = JFADistanceFilter()
        finalize.inputImage = seeds
        finalize.maxDistance = max(1.0, diag) // guard against divide by 0
        
        return finalize.outputImage ?? clampedMask
    }
    
    private static func makeJFASteps(for size: CGSize) -> [Int] {
        let maxDim = Int(max(size.width, size.height))
        if maxDim <= 1 { return [1] }
        var s = 1
        while s < maxDim { s <<= 1 }
        // s is the first power-of-two >= maxDim; start from s and go down to 1
        var steps: [Int] = []
        while s >= 1 {
            steps.append(s)
            s >>= 1
        }
        return steps
    }
}

// MARK: - Metal-backed filters

final class JFAInitSeedsFilter: MetalCIFilter {
    @objc dynamic var threshold: Float = 0.2
    
    init() {
        super.init(
            resourceName: "JFADistance",
            functionName: "jfaInitSeeds",
            arguments: []
        )
    }
    
    override var outputImage: CIImage? {
        guard inputImage != nil else { return nil }
        self.arguments = [threshold]
        return super.outputImage
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

final class JFAStepFilter: MetalCIFilter {
    @objc dynamic var step: Float = 1.0
    @objc dynamic var imgSize: CGSize = .zero
    
    init() {
        super.init(
            resourceName: "JFADistance",
            functionName: "jfaStep",
            arguments: []
        )
    }
    
    override var outputImage: CIImage? {
        guard let inputImage = inputImage else { return nil }
        // If caller didn't set imgSize, infer from input
        let size = imgSize == .zero ? inputImage.extent.size : imgSize
        let sizeVec = CIVector(x: size.width, y: size.height)
        self.arguments = [step, sizeVec]
        return super.outputImage
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

final class JFADistanceFilter: MetalCIFilter {
    @objc dynamic var maxDistance: Float = 1.0
    
    init() {
        super.init(
            resourceName: "JFADistance",
            functionName: "jfaDistance",
            arguments: []
        )
    }
    
    override var outputImage: CIImage? {
        guard inputImage != nil else { return nil }
        self.arguments = [maxDistance]
        return super.outputImage
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}