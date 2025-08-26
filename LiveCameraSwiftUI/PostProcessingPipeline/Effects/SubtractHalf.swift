//
//  SubtractHalf.swift
//  LiveCameraSwiftUI
//
//  Created by Mikołaj Wirkijowski on 26/08/2025.
//
import CoreImage


struct SubtractHalf: PostProcessingEffect {
    func apply(to image: CIImage) -> CIImage {
        let subtractHalfFilter = SubtractHalfFilter()
        subtractHalfFilter.inputImage = image

        return subtractHalfFilter.outputImage ?? image
    }
}

class SubtractHalfFilter: MetalCIFilter {

    init() {
        super.init(
            resourceName: "SubtractHalf",
            functionName: "subtractHalf"
        )
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
