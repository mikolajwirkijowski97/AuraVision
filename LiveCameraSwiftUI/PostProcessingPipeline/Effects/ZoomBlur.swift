//
//  ZoomBlur.swift
//  LiveCameraSwiftUI
//
//  Created by Mikołaj Wirkijowski on 25/08/2025.
//
import CoreImage
import CoreImage.CIFilterBuiltins

struct ZoomBlur: PostProcessingEffect {
    var intensity: Float = 10
    
    func apply(to image: CIImage) -> CIImage {
        let zoomBlurFilter = CIFilter.zoomBlur()
        zoomBlurFilter.inputImage = image
        zoomBlurFilter.center = CGPoint(x: image.extent.midX, y: image.extent.midY)
        zoomBlurFilter.amount = intensity

        return zoomBlurFilter.outputImage ?? image
    }
}
