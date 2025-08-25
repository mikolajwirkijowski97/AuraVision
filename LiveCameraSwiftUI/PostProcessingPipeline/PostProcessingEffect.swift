//
//  PostProcessingEffect.swift
//  LiveCameraSwiftUI
//
//  Created by Mikołaj Wirkijowski on 25/08/2025.
//
import CoreImage

// A simple protocol to be used in conjunction with the pp pipeline
protocol PostProcessingEffect {
    func apply(to image: CIImage) -> CIImage
}
