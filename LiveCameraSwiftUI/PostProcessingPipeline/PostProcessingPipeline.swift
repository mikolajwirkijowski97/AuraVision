//
//  PostProcessingPipeline.swift
//  LiveCameraSwiftUI
//
//  Created by Mikołaj Wirkijowski on 25/08/2025.
//
import CoreImage
import CoreImage.CIFilterBuiltins
import Vision

class PostProcessingPipeline {
    private var effects: [PostProcessingEffect] = []
    private lazy var personSegmentationRequest: VNGeneratePersonSegmentationRequest = {
        let request =  VNGeneratePersonSegmentationRequest()
        request.qualityLevel = .balanced
        return request
    }()

    init(effects: [PostProcessingEffect]? = nil) {
        self.effects = effects ?? []
    }
    
    /// As the whole app is about post processing the segmentation result mask
    /// so beware: `this function performs image segmentation`, then applies all effects to its result
    /// and finally combines the two images(image and the processed mask) into a resultImage
    public func apply(to image: CIImage) -> CIImage {
        
        guard var processedImage = getSegmentationMask(from: image) else { return image }
        for effect in effects {
            processedImage = effect.apply(to: processedImage)
        }
        return compositeMaskAndOriginalImage(mask: processedImage, originalImage: image)
    }
    
    /// Get a mask with people highlighted as white and the lack of them being neutral grey
    private func getSegmentationMask(from image: CIImage) -> CIImage? {
        let handler = VNImageRequestHandler(ciImage: image)
        
        do {
            try handler.perform([personSegmentationRequest])
            
            guard let mask = personSegmentationRequest.results?.first?.pixelBuffer else {
                return nil
            }
            
            var maskCIImage = CIImage(cvPixelBuffer: mask)
            
            maskCIImage = scaleMaskToFitOriginal(mask: maskCIImage, originalExtent: image.extent)
            return maskCIImage

        } catch {
            print("Vision request failed: \(error)")
            return nil
        }
    }

    private func scaleMaskToFitOriginal(mask: CIImage, originalExtent: CGRect) -> CIImage {
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
    
}
