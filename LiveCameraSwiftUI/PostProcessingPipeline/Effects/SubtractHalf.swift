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

class SubtractHalfFilter: CIFilter
{
    
    static var kernel: CIColorKernel = { () -> CIColorKernel in
        let url = Bundle.main.url(forResource: "SubtractHalf", withExtension: "ci.metallib")!
        let data = try! Data(contentsOf: url)
        
        do {
            return try CIColorKernel(functionName: "subtractHalf", fromMetalLibraryData: data)
        }
        catch {
            print("\(error)")
            fatalError("\(error)")
        }
    }()
    
    @objc dynamic var inputImage : CIImage?
    
    override var outputImage : CIImage!
    {
        guard let inputImage = self.inputImage else
        {
            return nil
        }
        
        let arguments = [inputImage] as [Any]
        
        return Self.kernel.apply(extent: inputImage.extent, arguments: arguments)
    }
    
}


